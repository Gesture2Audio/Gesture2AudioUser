import AVFoundation
import Foundation

struct IMUFrame: Codable {
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

struct GestureRecording: Codable {
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

struct GestureTrainingSet: Codable {
    let samples: [GestureRecording]
}

struct GesturePrediction: Identifiable {
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
    private struct TrainingFeature {
        let label: String
        let values: [Double]
    }

    private let targetFrames = 151
    private let neighborCount = 5
    private var trainingFeatures: [TrainingFeature] = []

    init() {
        loadBundledTrainingSet()
    }

    var isReady: Bool {
        !trainingFeatures.isEmpty
    }

    var trainingSampleCount: Int {
        trainingFeatures.count
    }

    func classify(frames: [IMUFrame]) -> GesturePrediction? {
        guard !trainingFeatures.isEmpty else { return nil }
        let features = featuresForFrames(frames)

        let nearest = trainingFeatures
            .map { item -> (label: String, distance: Double) in
                (item.label, squaredDistance(features, item.values))
            }
            .sorted { $0.distance < $1.distance }
            .prefix(neighborCount)

        var votes: [String: Double] = [:]
        for item in nearest {
            votes[item.label, default: 0] += 1.0 / max(item.distance, 0.000001)
        }

        guard let winner = votes.max(by: { $0.value < $1.value }) else { return nil }
        let total = votes.values.reduce(0, +)
        let confidence = total > 0 ? winner.value / total : 0

        return GesturePrediction(
            label: winner.key,
            displayName: Self.displayName(for: winner.key),
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

    private func loadBundledTrainingSet() {
        guard let url = Bundle.main.url(forResource: "bird_river_training", withExtension: "json") else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let trainingSet = try JSONDecoder().decode(GestureTrainingSet.self, from: data)
            trainingFeatures = trainingSet.samples
                .filter { $0.label == "bird" || $0.label == "river" }
                .map { TrainingFeature(label: $0.label, values: featuresForFrames($0.frames)) }
        } catch {
            trainingFeatures = []
        }
    }

    private func fixedLength(_ frames: [IMUFrame]) -> [IMUFrame] {
        guard let last = frames.last else { return [] }
        var result = Array(frames.prefix(targetFrames))
        while result.count < targetFrames {
            result.append(last)
        }
        return result
    }

    private func featuresForFrames(_ frames: [IMUFrame]) -> [Double] {
        let fixed = fixedLength(frames)
        guard !fixed.isEmpty else { return [] }

        let rows: [[Double]] = fixed.map { [$0.ax, $0.ay, $0.az, $0.gx, $0.gy, $0.gz] }
        var deltaRows: [[Double]] = []
        var sequenceFeatures: [Double] = []

        for index in rows.indices {
            let accelMagnitude = magnitude(rows[index][0], rows[index][1], rows[index][2])
            let gyroMagnitude = magnitude(rows[index][3], rows[index][4], rows[index][5])
            let delta: [Double]
            if index == rows.startIndex {
                delta = Array(repeating: 0, count: 6)
            } else {
                delta = zip(rows[index], rows[index - 1]).map { $0 - $1 }
            }

            deltaRows.append(delta)
            sequenceFeatures.append(contentsOf: rows[index])
            sequenceFeatures.append(accelMagnitude)
            sequenceFeatures.append(gyroMagnitude)
            sequenceFeatures.append(contentsOf: delta)
        }

        var summary: [Double] = []
        appendSummary(for: rows, to: &summary)
        appendSummary(for: deltaRows, to: &summary)
        sequenceFeatures.append(contentsOf: summary)
        return sequenceFeatures
    }

    private func appendSummary(for rows: [[Double]], to output: inout [Double]) {
        guard let first = rows.first else { return }
        let width = first.count

        for column in 0..<width {
            let values = rows.map { $0[column] }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
            let rms = sqrt(values.reduce(0) { $0 + ($1 * $1) } / Double(values.count))

            output.append(mean)
            output.append(sqrt(variance))
            output.append(values.min() ?? 0)
            output.append(values.max() ?? 0)
            output.append(rms)
        }
    }

    private func magnitude(_ x: Double, _ y: Double, _ z: Double) -> Double {
        sqrt(x * x + y * y + z * z)
    }

    private func squaredDistance(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let count = min(lhs.count, rhs.count)
        guard count > 0 else { return Double.greatestFiniteMagnitude }
        var total = 0.0
        for index in 0..<count {
            let diff = lhs[index] - rhs[index]
            total += diff * diff
        }
        return total / Double(count)
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
