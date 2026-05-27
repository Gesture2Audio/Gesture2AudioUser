import Foundation

struct IMUFrame: Decodable, Sendable {
    let elapsedSeconds: Double
    let timestampEpoch: Double
    let ax: Double
    let ay: Double
    let az: Double
    let gx: Double
    let gy: Double
    let gz: Double

    enum CodingKeys: String, CodingKey {
        case elapsedSeconds
        case elapsedSecondsSnake = "elapsed_seconds"
        case timestampEpoch
        case timestampEpochSnake = "timestamp_epoch"
        case ax
        case ay
        case az
        case gx
        case gy
        case gz
    }

    init(elapsedSeconds: Double, timestampEpoch: Double, ax: Double, ay: Double, az: Double, gx: Double, gy: Double, gz: Double) {
        self.elapsedSeconds = elapsedSeconds
        self.timestampEpoch = timestampEpoch
        self.ax = ax
        self.ay = ay
        self.az = az
        self.gx = gx
        self.gy = gy
        self.gz = gz
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        elapsedSeconds = try container.decodeIfPresent(Double.self, forKey: .elapsedSeconds)
            ?? container.decode(Double.self, forKey: .elapsedSecondsSnake)
        timestampEpoch = try container.decodeIfPresent(Double.self, forKey: .timestampEpoch)
            ?? container.decode(Double.self, forKey: .timestampEpochSnake)
        ax = try container.decode(Double.self, forKey: .ax)
        ay = try container.decode(Double.self, forKey: .ay)
        az = try container.decode(Double.self, forKey: .az)
        gx = try container.decode(Double.self, forKey: .gx)
        gy = try container.decode(Double.self, forKey: .gy)
        gz = try container.decode(Double.self, forKey: .gz)
    }
}

struct GestureRecording: Decodable, Sendable {
    let id: String?
    let sampleId: String?
    let label: String
    let sourceIndex: Int?
    let filename: String?
    let frames: [IMUFrame]

    enum CodingKeys: String, CodingKey {
        case id
        case sampleId
        case label
        case sourceIndex = "source_index"
        case filename
        case frames
    }
}

struct GestureTrainingSet: Decodable, Sendable {
    let samples: [GestureRecording]
}

struct GesturePrediction: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let displayName: String
    let confidence: Double
    let timestamp: Date

    var soundLayer: String {
        GestureClassifier.soundLayer(for: label)
    }
}

final class GestureClassifier {
    enum LoadStatus: Sendable {
        case ready(sampleCount: Int, modelType: String, selectedFeatureCount: Int)
        case missingResource
        case failedToDecode(String)

        var displayText: String {
            switch self {
            case .ready(let sampleCount, let modelType, let selectedFeatureCount):
                return "ready: \(modelType), \(sampleCount) samples, \(selectedFeatureCount) features"
            case .missingResource:
                return "model unavailable: bundled model file missing"
            case .failedToDecode(let message):
                return "model unavailable: \(message)"
            }
        }
    }

    private struct LogisticScaler: Decodable, Sendable {
        let mean: [Double]
        let scale: [Double]
    }

    private struct MulticlassClassifierDefinition: Decodable, Sendable {
        let classes: [Int]
        let coefficients: [[Double]]
        let intercepts: [Double]
        let regularizationC: Double?

        enum CodingKeys: String, CodingKey {
            case classes
            case coefficients
            case intercepts
            case regularizationC = "regularization_c"
        }
    }

    private struct SixGestureModel: Decodable, Sendable {
        let modelType: String
        let labels: [String]
        let displayNames: [String: String]
        let soundLayers: [String: String]
        let sampleCount: Int
        let featureCount: Int
        let selectedFeatureCount: Int
        let targetFrames: Int
        let sequenceFrames: Int
        let selectedFeatureIndices: [Int]
        let scaler: LogisticScaler
        let classifier: MulticlassClassifierDefinition

        enum CodingKeys: String, CodingKey {
            case modelType = "model_type"
            case labels
            case displayNames = "display_names"
            case soundLayers = "sound_layers"
            case sampleCount = "sample_count"
            case featureCount = "feature_count"
            case selectedFeatureCount = "selected_feature_count"
            case targetFrames = "target_frames"
            case sequenceFrames = "sequence_frames"
            case selectedFeatureIndices = "selected_feature_indices"
            case scaler
            case classifier
        }
    }

    private var model: SixGestureModel?
    private(set) var loadStatus: LoadStatus = .missingResource

    init() {
        loadBundledModel()
    }

    var isReady: Bool {
        model != nil
    }

    var trainingSampleCount: Int {
        model?.sampleCount ?? 0
    }

    func classify(frames: [IMUFrame]) -> GesturePrediction? {
        guard let model else { return nil }
        let features = featuresForFrames(frames, targetFrames: model.targetFrames, sequenceFrames: model.sequenceFrames)
        guard features.count == model.featureCount else { return nil }
        guard model.selectedFeatureIndices.count == model.selectedFeatureCount else { return nil }

        var selectedFeatures: [Double] = []
        selectedFeatures.reserveCapacity(model.selectedFeatureIndices.count)
        for index in model.selectedFeatureIndices {
            guard index >= 0,
                  index < features.count,
                  index < model.scaler.mean.count,
                  index < model.scaler.scale.count else { return nil }
            let value = features[index]
            let mean = model.scaler.mean[index]
            let scale = model.scaler.scale[index]
            let denominator = abs(scale) < 0.0000001 ? 1.0 : scale
            selectedFeatures.append((value - mean) / denominator)
        }

        var scoredLabels: [(label: String, score: Double)] = []
        for rowIndex in model.classifier.coefficients.indices {
            guard rowIndex < model.classifier.intercepts.count else { return nil }
            let classIndex = rowIndex < model.classifier.classes.count ? model.classifier.classes[rowIndex] : rowIndex
            guard classIndex >= 0, classIndex < model.labels.count else { return nil }

            let coefficients = model.classifier.coefficients[rowIndex]
            guard coefficients.count == selectedFeatures.count else { return nil }
            let score = zip(selectedFeatures, coefficients).reduce(model.classifier.intercepts[rowIndex]) { partial, item in
                partial + (item.0 * item.1)
            }
            scoredLabels.append((label: model.labels[classIndex], score: score))
        }

        guard let best = scoredLabels.enumerated().max(by: { $0.element.score < $1.element.score }) else {
            return nil
        }
        let confidence = softmaxProbability(for: best.offset, scores: scoredLabels.map { $0.score })
        let winnerLabel = best.element.label

        return GesturePrediction(
            label: winnerLabel,
            displayName: model.displayNames[winnerLabel] ?? Self.displayName(for: winnerLabel),
            confidence: confidence,
            timestamp: Date()
        )
    }

    static func displayName(for label: String) -> String {
        switch label {
        case "leaf":
            return "Leaf"
        case "tree":
            return "Tree"
        case "bird":
            return "Bird"
        case "ocean":
            return "Wave"
        case "river":
            return "Fish"
        case "rain":
            return "Cloud"
        default:
            return label.capitalized
        }
    }

    static func soundLayer(for label: String) -> String {
        switch label {
        case "leaf":
            return "Rustling leaves"
        case "tree":
            return "Forest sound"
        case "bird":
            return "Bird chirps"
        case "ocean":
            return "Ocean waves"
        case "river":
            return "River sound"
        case "rain":
            return "Rain sound"
        default:
            return label.capitalized
        }
    }

    private func loadBundledModel() {
        guard let url = Bundle.main.url(forResource: "six_gesture_model", withExtension: "json") else {
            loadStatus = .missingResource
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decodedModel = try JSONDecoder().decode(SixGestureModel.self, from: data)
            model = decodedModel
            loadStatus = .ready(
                sampleCount: decodedModel.sampleCount,
                modelType: "six-gesture logistic model",
                selectedFeatureCount: decodedModel.selectedFeatureCount
            )
        } catch {
            model = nil
            loadStatus = .failedToDecode(error.localizedDescription)
        }
    }

    private func featuresForFrames(_ frames: [IMUFrame], targetFrames: Int, sequenceFrames: Int) -> [Double] {
        let correctedRows = baselineCorrectedRows(frames)
        guard !correctedRows.isEmpty else { return [] }

        let resampled = resample(rows: correctedRows, targetCount: targetFrames)
        let signals = resampled.map { row -> [Double] in
            let accelMagnitude = magnitude(row[0], row[1], row[2])
            let gyroMagnitude = magnitude(row[3], row[4], row[5])
            return row + [accelMagnitude, gyroMagnitude]
        }
        let delta = diffRows(signals)
        let delta2 = diffRows(delta)

        var featureVector: [Double] = []
        featureVector.reserveCapacity(652)
        appendBlockSummary(signals, signalWidth: 8, to: &featureVector)
        appendBlockSummary(delta, signalWidth: 8, to: &featureVector)
        appendBlockSummary(delta2, signalWidth: 8, to: &featureVector)
        appendCorrelations(signals, signalWidth: 8, to: &featureVector)
        featureVector.append(contentsOf: resample(rows: correctedRows, targetCount: sequenceFrames).flatMap { $0 })
        return featureVector
    }

    private func baselineCorrectedRows(_ frames: [IMUFrame]) -> [[Double]] {
        let rows = frames.map { [$0.ax, $0.ay, $0.az, $0.gx, $0.gy, $0.gz] }
        guard let first = rows.first else { return [] }

        let baselineCount = min(5, rows.count)
        var baseline = Array(repeating: 0.0, count: first.count)
        for row in rows.prefix(baselineCount) {
            for index in 0..<baseline.count {
                baseline[index] += row[index]
            }
        }
        baseline = baseline.map { $0 / Double(baselineCount) }

        return rows.map { row in
            zip(row, baseline).map { value, mean in value - mean }
        }
    }

    private func resample(rows: [[Double]], targetCount: Int) -> [[Double]] {
        guard targetCount > 0, let first = rows.first else { return [] }
        guard rows.count != targetCount else { return rows }
        guard rows.count > 1, targetCount > 1 else {
            return Array(repeating: first, count: targetCount)
        }

        let sourceLastIndex = Double(rows.count - 1)
        let targetLastIndex = Double(targetCount - 1)
        return (0..<targetCount).map { targetIndex in
            let position = Double(targetIndex) * sourceLastIndex / targetLastIndex
            let lowerIndex = Int(floor(position))
            let upperIndex = min(lowerIndex + 1, rows.count - 1)
            let weight = position - Double(lowerIndex)
            return zip(rows[lowerIndex], rows[upperIndex]).map { lower, upper in
                lower + ((upper - lower) * weight)
            }
        }
    }

    private func diffRows(_ rows: [[Double]]) -> [[Double]] {
        guard rows.count > 1 else { return [] }
        return (1..<rows.count).map { index in
            zip(rows[index], rows[index - 1]).map { current, previous in
                current - previous
            }
        }
    }

    private func appendBlockSummary(_ block: [[Double]], signalWidth: Int, to output: inout [Double]) {
        guard !block.isEmpty else {
            output.append(contentsOf: Array(repeating: 0.0, count: signalWidth * 10))
            return
        }

        let columns = (0..<signalWidth).map { column in block.map { $0[column] } }

        output.append(contentsOf: columns.map { mean($0) })
        output.append(contentsOf: columns.map { standardDeviation($0) })
        output.append(contentsOf: columns.map { $0.min() ?? 0 })
        output.append(contentsOf: columns.map { $0.max() ?? 0 })

        for fraction in [0.10, 0.25, 0.50, 0.75, 0.90] {
            output.append(contentsOf: columns.map { percentile(values: $0, fraction: fraction) })
        }

        output.append(contentsOf: columns.map { values in
            values.reduce(0) { $0 + ($1 * $1) } / Double(values.count)
        })
    }

    private func appendCorrelations(_ rows: [[Double]], signalWidth: Int, to output: inout [Double]) {
        guard !rows.isEmpty else {
            output.append(contentsOf: Array(repeating: 0.0, count: signalWidth * (signalWidth - 1) / 2))
            return
        }

        let columns = (0..<signalWidth).map { column in blockColumn(rows, column: column) }
        for left in 0..<signalWidth {
            for right in (left + 1)..<signalWidth {
                output.append(correlation(columns[left], columns[right]))
            }
        }
    }

    private func blockColumn(_ rows: [[Double]], column: Int) -> [Double] {
        rows.map { $0[column] }
    }

    private func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let average = mean(values)
        let variance = values.reduce(0) { $0 + pow($1 - average, 2) } / Double(values.count)
        return sqrt(variance)
    }

    private func correlation(_ xValues: [Double], _ yValues: [Double]) -> Double {
        guard xValues.count == yValues.count, !xValues.isEmpty else { return 0 }
        let xMean = mean(xValues)
        let yMean = mean(yValues)
        var numerator = 0.0
        var xEnergy = 0.0
        var yEnergy = 0.0

        for index in xValues.indices {
            let xCentered = xValues[index] - xMean
            let yCentered = yValues[index] - yMean
            numerator += xCentered * yCentered
            xEnergy += xCentered * xCentered
            yEnergy += yCentered * yCentered
        }

        let denominator = sqrt(xEnergy * yEnergy)
        return denominator < 0.0000001 ? 0 : numerator / denominator
    }

    private func magnitude(_ x: Double, _ y: Double, _ z: Double) -> Double {
        sqrt(x * x + y * y + z * z)
    }

    private func percentile(values: [Double], fraction: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sortedValues = values.sorted()
        let clampedFraction = min(max(fraction, 0), 1)
        let position = clampedFraction * Double(sortedValues.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        if lowerIndex == upperIndex {
            return sortedValues[lowerIndex]
        }
        let weight = position - Double(lowerIndex)
        let lowerValue = sortedValues[lowerIndex]
        let upperValue = sortedValues[upperIndex]
        return lowerValue + ((upperValue - lowerValue) * weight)
    }

    private func softmaxProbability(for selectedIndex: Int, scores: [Double]) -> Double {
        guard selectedIndex >= 0, selectedIndex < scores.count else { return 0 }
        let maxScore = scores.max() ?? 0
        let exponentials = scores.map { exp($0 - maxScore) }
        let denominator = exponentials.reduce(0, +)
        return denominator < 0.0000001 ? 0 : exponentials[selectedIndex] / denominator
    }
}
