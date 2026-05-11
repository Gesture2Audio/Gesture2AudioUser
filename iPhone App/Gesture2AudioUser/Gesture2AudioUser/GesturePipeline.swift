import AVFoundation
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
        switch label {
        case "bird":
            return "Bird chirps"
        case "river":
            return "River sound"
        default:
            return label.capitalized
        }
    }
}

final class GestureClassifier {
    enum LoadStatus: Sendable {
        case ready(sampleCount: Int, modelType: String)
        case missingResource
        case failedToDecode(String)

        var displayText: String {
            switch self {
            case .ready(let sampleCount, let modelType):
                return "ready: \(modelType), \(sampleCount) training samples"
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

    private struct LogisticClassifierDefinition: Decodable, Sendable {
        let positiveLabel: String
        let coefficients: [Double]
        let intercept: Double

        enum CodingKeys: String, CodingKey {
            case positiveLabel = "positive_label"
            case coefficients
            case intercept
        }
    }

    private struct GestureLogisticModel: Decodable, Sendable {
        let modelType: String
        let labels: [String]
        let displayNames: [String: String]
        let sampleCount: Int
        let featureCount: Int
        let targetFrames: Int
        let downsampleBins: Int
        let scaler: LogisticScaler
        let classifier: LogisticClassifierDefinition

        enum CodingKeys: String, CodingKey {
            case modelType = "model_type"
            case labels
            case displayNames = "display_names"
            case sampleCount = "sample_count"
            case featureCount = "feature_count"
            case targetFrames = "target_frames"
            case downsampleBins = "downsample_bins"
            case scaler
            case classifier
        }
    }

    private var model: GestureLogisticModel?
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
        let features = featuresForFrames(frames, targetFrames: model.targetFrames, downsampleBins: model.downsampleBins)
        guard features.count == model.featureCount else { return nil }

        let standardized = zip(zip(features, model.scaler.mean), model.scaler.scale).map { packed -> Double in
            let ((value, mean), scale) = packed
            let denominator = abs(scale) < 0.0000001 ? 1.0 : scale
            return (value - mean) / denominator
        }

        guard standardized.count == model.classifier.coefficients.count else { return nil }

        let logit = zip(standardized, model.classifier.coefficients).reduce(model.classifier.intercept) { partial, item in
            partial + (item.0 * item.1)
        }
        let positiveProbability = sigmoid(logit)
        let negativeProbability = 1.0 - positiveProbability

        let positiveLabel = model.classifier.positiveLabel
        let negativeLabel = model.labels.first { $0 != positiveLabel } ?? model.labels.first ?? positiveLabel
        let winnerLabel: String
        let confidence: Double
        if positiveProbability >= negativeProbability {
            winnerLabel = positiveLabel
            confidence = positiveProbability
        } else {
            winnerLabel = negativeLabel
            confidence = negativeProbability
        }

        return GesturePrediction(
            label: winnerLabel,
            displayName: model.displayNames[winnerLabel] ?? Self.displayName(for: winnerLabel),
            confidence: confidence,
            timestamp: Date()
        )
    }

    static func displayName(for label: String) -> String {
        switch label {
        case "bird":
            return "Bird"
        case "river":
            return "Fish"
        default:
            return label.capitalized
        }
    }

    private func loadBundledModel() {
        guard let url = Bundle.main.url(forResource: "bird_river_model", withExtension: "json") else {
            loadStatus = .missingResource
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decodedModel = try JSONDecoder().decode(GestureLogisticModel.self, from: data)
            model = decodedModel
            loadStatus = .ready(sampleCount: decodedModel.sampleCount, modelType: "trained logistic model")
        } catch {
            model = nil
            loadStatus = .failedToDecode(error.localizedDescription)
        }
    }

    private func fixedLength(_ frames: [IMUFrame], targetFrames: Int) -> [IMUFrame] {
        guard let last = frames.last else { return [] }
        var result = Array(frames.prefix(targetFrames))
        while result.count < targetFrames {
            result.append(last)
        }
        return result
    }

    private func featuresForFrames(_ frames: [IMUFrame], targetFrames: Int, downsampleBins: Int) -> [Double] {
        let fixed = fixedLength(frames, targetFrames: targetFrames)
        guard !fixed.isEmpty else { return [] }

        let rows: [[Double]] = fixed.map {
            let accelMagnitude = magnitude($0.ax, $0.ay, $0.az)
            let gyroMagnitude = magnitude($0.gx, $0.gy, $0.gz)
            return [$0.ax, $0.ay, $0.az, $0.gx, $0.gy, $0.gz, accelMagnitude, gyroMagnitude]
        }

        var deltaRows: [[Double]] = []
        for index in rows.indices {
            if index == rows.startIndex {
                deltaRows.append(Array(repeating: 0, count: rows[index].count))
            } else {
                deltaRows.append(zip(rows[index], rows[index - 1]).map { current, previous in
                    current - previous
                })
            }
        }

        var featureVector: [Double] = []
        featureVector.append(contentsOf: downsample(rows: rows, bins: downsampleBins).flatMap { $0 })
        appendSummary(for: rows, to: &featureVector)
        appendSummary(for: deltaRows, to: &featureVector)
        return featureVector
    }

    private func appendSummary(for rows: [[Double]], to output: inout [Double]) {
        guard let first = rows.first else { return }
        let width = first.count

        for column in 0..<width {
            let values = rows.map { $0[column] }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
            let rms = sqrt(values.reduce(0) { $0 + ($1 * $1) } / Double(values.count))
            let absValues = values.map { abs($0) }
            let sorted = values.sorted()

            output.append(mean)
            output.append(sqrt(variance))
            output.append(values.min() ?? 0)
            output.append(values.max() ?? 0)
            output.append(rms)
            output.append(absValues.reduce(0, +) / Double(absValues.count))
            output.append(percentile(sortedValues: sorted, fraction: 0.25))
            output.append(percentile(sortedValues: sorted, fraction: 0.50))
            output.append(percentile(sortedValues: sorted, fraction: 0.75))
            output.append(absValues.max() ?? 0)
        }
    }

    private func downsample(rows: [[Double]], bins: Int) -> [[Double]] {
        guard bins > 0, !rows.isEmpty else { return [] }
        let width = rows[0].count
        let count = rows.count
        return (0..<bins).map { bin in
            let start = bin * count / bins
            let end = max(start + 1, (bin + 1) * count / bins)
            let segment = rows[start..<min(end, count)]
            var averages = Array(repeating: 0.0, count: width)
            for row in segment {
                for index in 0..<width {
                    averages[index] += row[index]
                }
            }
            let divisor = Double(segment.count)
            return averages.map { $0 / divisor }
        }
    }

    private func magnitude(_ x: Double, _ y: Double, _ z: Double) -> Double {
        sqrt(x * x + y * y + z * z)
    }

    private func percentile(sortedValues: [Double], fraction: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0 }
        let clampedFraction = min(max(fraction, 0), 1)
        let position = clampedFraction * Double(sortedValues.count - 1)
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = Int(position.rounded(.up))
        if lowerIndex == upperIndex {
            return sortedValues[lowerIndex]
        }
        let weight = position - Double(lowerIndex)
        let lowerValue = sortedValues[lowerIndex]
        let upperValue = sortedValues[upperIndex]
        return lowerValue + ((upperValue - lowerValue) * weight)
    }

    private func sigmoid(_ value: Double) -> Double {
        if value >= 0 {
            let exponent = exp(-value)
            return 1 / (1 + exponent)
        }
        let exponent = exp(value)
        return exponent / (1 + exponent)
    }
}

final class SoundscapeEngine {
    private let engine = AVAudioEngine()
    private let birdNode = AVAudioPlayerNode()
    private let riverNode = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    private var activeLabels: Set<String> = []
    private var fadeTimers: [String: Timer] = [:]

    var activeLayers: [String] {
        activeLabels.sorted().map {
            $0 == "bird" ? "Bird chirps" : "River sound"
        }
    }

    init() {
        engine.attach(birdNode)
        engine.attach(riverNode)
        engine.connect(birdNode, to: engine.mainMixerNode, format: format)
        engine.connect(riverNode, to: engine.mainMixerNode, format: format)
        birdNode.volume = 0
        riverNode.volume = 0
    }

    func activate(label: String) {
        do {
            try configureAudioSession()
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            return
        }

        switch label {
        case "bird":
            if !birdNode.isPlaying {
                birdNode.scheduleBuffer(makeBirdBuffer(), at: nil, options: .loops)
                birdNode.play()
            }
            fade(node: birdNode, key: label, target: 0.72)
            activeLabels.insert(label)
        case "river":
            if !riverNode.isPlaying {
                riverNode.scheduleBuffer(makeRiverBuffer(), at: nil, options: .loops)
                riverNode.play()
            }
            fade(node: riverNode, key: label, target: 0.58)
            activeLabels.insert(label)
        default:
            break
        }
    }

    func reset() {
        fadeTimers.values.forEach { $0.invalidate() }
        fadeTimers.removeAll()
        birdNode.stop()
        riverNode.stop()
        birdNode.volume = 0
        riverNode.volume = 0
        activeLabels.removeAll()
    }

    private func configureAudioSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        #endif
    }

    private func fade(node: AVAudioPlayerNode, key: String, target: Float) {
        fadeTimers[key]?.invalidate()
        let steps: Float = 20
        let start = node.volume
        var currentStep: Float = 0
        fadeTimers[key] = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { timer in
            currentStep += 1
            let progress = min(1, currentStep / steps)
            node.volume = start + (target - start) * progress
            if progress >= 1 {
                timer.invalidate()
            }
        }
    }

    private func makeBirdBuffer() -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(format.sampleRate * 1.8)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let chirps: [(start: Double, freq: Double)] = [(0.18, 1800), (0.38, 2300), (1.05, 2050), (1.30, 2500)]
        fill(buffer: buffer) { time in
            var sample = 0.0
            for chirp in chirps {
                let local = time - chirp.start
                if local >= 0 && local <= 0.12 {
                    let envelope = sin(.pi * local / 0.12)
                    let sweep = chirp.freq + local * 950
                    sample += sin(2 * .pi * sweep * time) * envelope * 0.35
                }
            }
            return Float(sample)
        }
        return buffer
    }

    private func makeRiverBuffer() -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(format.sampleRate * 2.4)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        var previous = 0.0
        fill(buffer: buffer) { _ in
            let noise = Double.random(in: -1...1)
            previous = previous * 0.94 + noise * 0.06
            return Float(previous * 0.55)
        }
        return buffer
    }

    private func fill(buffer: AVAudioPCMBuffer, generator: (Double) -> Float) {
        guard let channels = buffer.floatChannelData else { return }
        let count = Int(buffer.frameLength)
        for index in 0..<count {
            let value = generator(Double(index) / format.sampleRate)
            channels[0][index] = value
            channels[1][index] = value
        }
    }
}
