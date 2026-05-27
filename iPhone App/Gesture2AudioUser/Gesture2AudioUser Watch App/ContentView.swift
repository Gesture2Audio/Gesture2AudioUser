//
//  ContentView.swift
//  Gesture2AudioUser Watch App
//
//  Created by Nilesh Balapitiya Badugei on 11/5/2026.
//

import SwiftUI
import CoreMotion
import WatchConnectivity
import Foundation
import Combine

enum CollectionLabel: String, CaseIterable, Identifiable {
    case leaf
    case tree
    case bird
    case ocean
    case river
    case rain

    var id: String { rawValue }

    var sourceGesture: String {
        switch self {
        case .ocean:
            return "ocean_wave"
        case .river:
            return "fish"
        case .rain:
            return "cloud"
        case .leaf, .tree, .bird:
            return rawValue
        }
    }

    var soundHint: String {
        switch self {
        case .leaf:
            return "rustling_leaves"
        case .tree:
            return "forest_sound"
        case .bird:
            return "bird_chirps"
        case .ocean:
            return "ocean_sound"
        case .river:
            return "river_flowing_sound"
        case .rain:
            return "rain_sound"
        }
    }
}

struct GestureFrame: Codable {
    let sampleClass: String
    let elapsedSeconds: Double
    let timestampEpoch: Double
    let ax: Double
    let ay: Double
    let az: Double
    let gx: Double
    let gy: Double
    let gz: Double
}

struct GestureCapture: Codable {
    let sampleId: String
    let day: Int
    let label: String
    let sourceGesture: String
    let soundHint: String
    let createdAtEpoch: Double
    let sampleRateHz: Double
    let durationSeconds: Double
    let frames: [GestureFrame]
}

private struct MotionTelemetrySnapshot {
    var ax = 0.0
    var ay = 0.0
    var az = 0.0
    var gx = 0.0
    var gy = 0.0
    var gz = 0.0
    var roll = 0.0
    var pitch = 0.0
    var yaw = 0.0

    init() {}

    init(motion: CMDeviceMotion) {
        ax = motion.userAcceleration.x
        ay = motion.userAcceleration.y
        az = motion.userAcceleration.z
        gx = motion.rotationRate.x
        gy = motion.rotationRate.y
        gz = motion.rotationRate.z
        roll = motion.attitude.roll
        pitch = motion.attitude.pitch
        yaw = motion.attitude.yaw
    }
}

struct ContentView: View {
    @StateObject private var imu = IMUManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    captureDial
                    statusPanel
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .topLeading)
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.black, Color(red: 0.04, green: 0.08, blue: 0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .onAppear {
            imu.start()
        }
        .onDisappear {
            imu.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                imu.start()
            case .background:
                imu.stop(reason: "Capture interrupted while the watch app moved to the background.")
            case .inactive:
                break
            default:
                break
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.08), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text("Gesture2Audio")
                    .font(.headline)
                Text("Shake, draw, listen")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            ConnectionPill(isReachable: imu.phoneLinkStatus == "reachable")
        }
    }

    private var captureDial: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: max(0.02, imu.captureProgress))
                    .stroke(
                        captureColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.15), value: imu.captureProgress)

                VStack(spacing: 2) {
                    Image(systemName: captureIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(captureColor)
                    Text(timerText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(captureInstruction)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)

            Text(imu.shakeDetected ? "Shake detected" : imu.captureStateText)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(captureColor)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var statusPanel: some View {
        VStack(spacing: 8) {
            MetricRow(
                icon: "bolt.fill",
                title: "Shake trigger",
                value: "\(imu.shakeCount)"
            )
            MetricRow(
                icon: "iphone",
                title: "Sent to phone",
                value: "\(imu.savedCount)"
            )
            MetricRow(
                icon: "timer",
                title: "Capture window",
                value: "3.0s"
            )

            if let statusMessage = imu.statusMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(3)
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
        }
        .font(.caption2)
        .padding(10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private var timerText: String {
        if imu.captureRemainingSeconds > 0 {
            return String(format: "%.1f", imu.captureRemainingSeconds)
        }
        return "3.0"
    }

    private var captureInstruction: String {
        switch imu.captureStateText {
        case "Capturing":
            return "Draw in the air"
        case let state where state.hasPrefix("Saved"):
            return "Gesture sent"
        case "Saving...":
            return "Sending"
        default:
            return "Quick shake to start"
        }
    }

    private var captureIcon: String {
        switch imu.captureStateText {
        case "Capturing":
            return "scribble.variable"
        case let state where state.hasPrefix("Saved"):
            return "checkmark"
        case "Saving...":
            return "arrow.up"
        default:
            return "hand.raised.fill"
        }
    }

    private var captureColor: Color {
        if imu.captureStateText == "Capturing" {
            return .teal
        }
        if imu.captureStateText.hasPrefix("Saved") {
            return .green
        }
        if imu.shakeDetected {
            return .green
        }
        return .orange
    }
}

#Preview {
    ContentView()
}

private struct ConnectionPill: View {
    let isReachable: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isReachable ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(isReachable ? "Phone" : "Offline")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08), in: Capsule())
    }
}

private struct MetricRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 18, height: 18)
                .background(Color.white.opacity(0.08), in: Circle())
            Text(title)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}

final class IMUManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let updateQueue = OperationQueue()
    private let shakeDetector = ShakeDetector()
    private let watchBridge = WatchBridge.shared

    @Published var selectedLabel: CollectionLabel = .leaf
    @Published var selectedDay = 1
    @Published var statusMessage: String?
    @Published var shakeDetected = false
    @Published var shakeCount = 0
    @Published var phoneLinkStatus = "not reachable"
    @Published var captureRemainingSeconds: Double = 0
    @Published var captureProgress: Double = 0
    @Published var captureStateText = "Shake to start"
    @Published var savedCount = 0

    private var shakeIndicatorResetWorkItem: DispatchWorkItem?
    private var isCapturing = false
    private var captureStartTimestamp: TimeInterval = 0
    private var captureStartEpoch: TimeInterval = 0
    private let captureDurationSeconds: TimeInterval = 3.0
    private let sampleRateHz = 50.0
    private let captureStallTimeoutSeconds: TimeInterval = 1.0
    private var frameBuffer: [GestureFrame] = []
    private var latestMotionSnapshot = MotionTelemetrySnapshot()
    private var captureStallWorkItem: DispatchWorkItem?

    init() {
        watchBridge.onReachabilityChange = { [weak self] reachable in
            DispatchQueue.main.async {
                self?.phoneLinkStatus = reachable ? "reachable" : "not reachable"
            }
        }

        watchBridge.onLabelReceived = { [weak self] rawLabel in
            guard let label = CollectionLabel(rawValue: rawLabel) else { return }
            DispatchQueue.main.async {
                self?.selectedLabel = label
            }
        }
        watchBridge.onDayReceived = { [weak self] day in
            let bounded = max(1, min(2, day))
            DispatchQueue.main.async {
                self?.selectedDay = bounded
            }
        }
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            statusMessage = "Device motion is unavailable."
            return
        }

        statusMessage = nil
        motionManager.deviceMotionUpdateInterval = 1.0 / sampleRateHz

        if motionManager.isDeviceMotionActive {
            return
        }

        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: updateQueue) { [weak self] motion, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    self.statusMessage = self.readableMotionError(from: error)
                }
                return
            }

            guard let motion else { return }

            DispatchQueue.main.async {
                self.statusMessage = nil
                self.latestMotionSnapshot = MotionTelemetrySnapshot(motion: motion)

                let didShake = self.shakeDetector.process(
                    userAcceleration: motion.userAcceleration,
                    rotationRate: motion.rotationRate,
                    timestamp: motion.timestamp
                )

                if didShake {
                    self.handleShakeDetected(at: motion.timestamp)
                }

                self.captureIfNeeded(motion: motion)
                self.publishCurrentState()
            }
        }
    }

    func stop(reason: String? = nil) {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        if isCapturing {
            cancelCapture(reason: reason ?? "Capture interrupted.")
        } else {
            cancelCaptureStallTimeout()
        }
    }

    private func handleShakeDetected(at timestamp: TimeInterval) {
        guard !isCapturing else { return }

        shakeDetected = true
        shakeCount += 1
        captureStateText = "Capturing"
        captureStartTimestamp = timestamp
        captureStartEpoch = Date().timeIntervalSince1970
        captureRemainingSeconds = captureDurationSeconds
        captureProgress = 0
        isCapturing = true
        frameBuffer.removeAll(keepingCapacity: true)
        statusMessage = nil
        refreshCaptureStallTimeout()

        shakeIndicatorResetWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.shakeDetected = false
        }
        shakeIndicatorResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func captureIfNeeded(motion: CMDeviceMotion) {
        guard isCapturing else { return }
        refreshCaptureStallTimeout()

        let elapsed = motion.timestamp - captureStartTimestamp
        let remaining = max(0, captureDurationSeconds - elapsed)
        captureRemainingSeconds = remaining
        captureProgress = min(1, elapsed / captureDurationSeconds)

        frameBuffer.append(
            GestureFrame(
                sampleClass: selectedLabel.rawValue,
                elapsedSeconds: elapsed,
                timestampEpoch: captureStartEpoch + elapsed,
                ax: motion.userAcceleration.x,
                ay: motion.userAcceleration.y,
                az: motion.userAcceleration.z,
                gx: motion.rotationRate.x,
                gy: motion.rotationRate.y,
                gz: motion.rotationRate.z
            )
        )

        if elapsed < captureDurationSeconds {
            return
        }

        cancelCaptureStallTimeout()
        isCapturing = false
        captureRemainingSeconds = 0
        captureProgress = 1
        captureStateText = "Saving..."

        let capture = GestureCapture(
            sampleId: UUID().uuidString,
            day: selectedDay,
            label: selectedLabel.rawValue,
            sourceGesture: selectedLabel.sourceGesture,
            soundHint: selectedLabel.soundHint,
            createdAtEpoch: Date().timeIntervalSince1970,
            sampleRateHz: sampleRateHz,
            durationSeconds: captureDurationSeconds,
            frames: frameBuffer
        )

        watchBridge.sendCapture(capture)
        savedCount += 1
        statusMessage = nil
        captureStateText = "Saved \(savedCount)"

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if !self.isCapturing {
                self.captureStateText = "Shake to start"
                self.captureProgress = 0
            }
        }
    }

    private func publishCurrentState(forceDelivery: Bool = false) {
        let payload: [String: Any] = [
            "type": "live",
            "day": selectedDay,
            "label": selectedLabel.rawValue,
            "source_gesture": selectedLabel.sourceGesture,
            "sound_hint": selectedLabel.soundHint,
            "status_message": statusMessage ?? "",
            "shake_detected": shakeDetected,
            "shake_count": shakeCount,
            "capture_remaining": captureRemainingSeconds,
            "capture_progress": captureProgress,
            "capture_state": captureStateText,
            "saved_count": savedCount,
            "ax": latestMotionSnapshot.ax,
            "ay": latestMotionSnapshot.ay,
            "az": latestMotionSnapshot.az,
            "gx": latestMotionSnapshot.gx,
            "gy": latestMotionSnapshot.gy,
            "gz": latestMotionSnapshot.gz,
            "roll": latestMotionSnapshot.roll,
            "pitch": latestMotionSnapshot.pitch,
            "yaw": latestMotionSnapshot.yaw,
        ]

        if forceDelivery {
            watchBridge.sendState(payload: payload)
        } else {
            watchBridge.sendLive(payload: payload)
        }
    }

    private func refreshCaptureStallTimeout() {
        guard isCapturing else {
            cancelCaptureStallTimeout()
            return
        }

        captureStallWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.cancelCapture(reason: "Capture interrupted because watch motion updates stalled.")
        }
        captureStallWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + captureStallTimeoutSeconds, execute: work)
    }

    private func cancelCaptureStallTimeout() {
        captureStallWorkItem?.cancel()
        captureStallWorkItem = nil
    }

    private func cancelCapture(reason: String) {
        guard isCapturing else { return }

        isCapturing = false
        captureStartTimestamp = 0
        captureStartEpoch = 0
        captureRemainingSeconds = 0
        captureProgress = 0
        captureStateText = "Shake to start"
        statusMessage = reason
        frameBuffer.removeAll(keepingCapacity: true)
        shakeIndicatorResetWorkItem?.cancel()
        shakeIndicatorResetWorkItem = nil
        shakeDetected = false
        cancelCaptureStallTimeout()
        publishCurrentState(forceDelivery: true)
    }

    private func readableMotionError(from error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("com.apple.coremotion.plist") || message.contains("operation not permitted") {
            return "Motion access blocked by system policy on this device."
        }
        return "Motion update failed."
    }
}

final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    var onReachabilityChange: ((Bool) -> Void)?
    var onLabelReceived: ((String) -> Void)?
    var onDayReceived: ((Int) -> Void)?

    private let session: WCSession?
    private let encoder = JSONEncoder()
    private let minimumLiveMessageInterval: TimeInterval = 0.15
    private let minimumContextUpdateInterval: TimeInterval = 0.50
    private var lastLiveMessageSentAt: TimeInterval = 0
    private var lastContextUpdateAt: TimeInterval = 0
    private var pendingLivePayload: [String: Any]?
    private var lastReportedReachability: Bool?

    private override init() {
        if WCSession.isSupported() {
            session = WCSession.default
        } else {
            session = nil
        }
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func sendLive(payload: [String: Any]) {
        pendingLivePayload = payload
        attemptLiveDelivery(forceContextUpdate: false)
    }

    func sendState(payload: [String: Any]) {
        pendingLivePayload = payload
        attemptLiveDelivery(forceContextUpdate: true)
    }

    func sendCapture(_ capture: GestureCapture) {
        guard let session else { return }
        activateIfNeeded()
        do {
            let data = try encoder.encode(capture)
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("\(capture.sampleId).json")
            try data.write(to: fileURL, options: .atomic)
            session.transferFile(fileURL, metadata: [
                "type": "capture",
                "day": capture.day,
                "label": capture.label,
                "sample_id": capture.sampleId,
            ])
        } catch {
            // Keep quiet for runtime stability; live status is still visible on phone.
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        reportReachability(session.isReachable)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        reportReachability(session.isReachable)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let rawLabel = applicationContext["selected_label"] as? String {
            onLabelReceived?(rawLabel)
        }
        if let rawDay = applicationContext["selected_day"] as? NSNumber {
            onDayReceived?(rawDay.intValue)
        } else if let rawDay = applicationContext["selected_day"] as? Int {
            onDayReceived?(rawDay)
        }
    }

    private func activateIfNeeded() {
        guard let session, session.activationState == .notActivated else { return }
        session.activate()
    }

    private func attemptLiveDelivery(forceContextUpdate: Bool) {
        guard let session, let payload = pendingLivePayload else { return }
        activateIfNeeded()

        let now = Date().timeIntervalSinceReferenceDate
        var delivered = false

        if session.activationState == .activated,
            session.isReachable,
            (now - lastLiveMessageSentAt) >= minimumLiveMessageInterval {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
            lastLiveMessageSentAt = now
            delivered = true
        }

        if forceContextUpdate || (now - lastContextUpdateAt) >= minimumContextUpdateInterval {
            do {
                try session.updateApplicationContext(payload)
                lastContextUpdateAt = now
                delivered = true
            } catch {
                // Keep the latest payload pending so a later attempt can deliver it.
            }
        }

        if delivered {
            pendingLivePayload = nil
        }

        reportReachability(session.isReachable)
    }

    private func reportReachability(_ reachable: Bool) {
        guard lastReportedReachability != reachable else { return }
        lastReportedReachability = reachable
        onReachabilityChange?(reachable)
    }
}

final class ShakeDetector {
    private var peakTimestamps: [TimeInterval] = []
    private var strongPeakTimestamps: [TimeInterval] = []
    private var energySamples: [(time: TimeInterval, value: Double)] = []
    private var lastPeakTime: TimeInterval = 0
    private var cooldownUntil: TimeInterval = 0

    private let accelMediumThreshold = 0.85
    private let accelStrongThreshold = 1.15
    private let gyroMediumThreshold = 2.20
    private let gyroStrongThreshold = 3.30
    private let minimumPeaksForShake = 3
    private let minimumStrongPeaksForShake = 1
    private let shakeWindowSeconds: TimeInterval = 0.80
    private let minimumPeakSpacing: TimeInterval = 0.07
    private let minimumBurstRMS = 1.30
    private let cooldownSeconds: TimeInterval = 0.90

    func process(userAcceleration: CMAcceleration, rotationRate: CMRotationRate, timestamp: TimeInterval) -> Bool {
        if timestamp < cooldownUntil {
            return false
        }

        let accelMagnitude = magnitude(userAcceleration.x, userAcceleration.y, userAcceleration.z)
        let gyroMagnitude = magnitude(rotationRate.x, rotationRate.y, rotationRate.z)
        let burstEnergy = accelMagnitude + 0.22 * gyroMagnitude
        let isPeak =
            (accelMagnitude >= accelMediumThreshold && gyroMagnitude >= gyroMediumThreshold) ||
            accelMagnitude >= accelStrongThreshold ||
            gyroMagnitude >= gyroStrongThreshold
        let isStrongPeak = accelMagnitude >= accelStrongThreshold || gyroMagnitude >= gyroStrongThreshold

        energySamples.append((timestamp, burstEnergy))

        if isPeak && (timestamp - lastPeakTime) >= minimumPeakSpacing {
            peakTimestamps.append(timestamp)
            lastPeakTime = timestamp
            if isStrongPeak {
                strongPeakTimestamps.append(timestamp)
            }
        }

        let keepAfter = timestamp - shakeWindowSeconds
        peakTimestamps.removeAll { $0 < keepAfter }
        strongPeakTimestamps.removeAll { $0 < keepAfter }
        energySamples.removeAll { $0.time < keepAfter }

        let rmsEnergy = rootMeanSquare(energySamples.map(\.value))

        if peakTimestamps.count >= minimumPeaksForShake &&
            strongPeakTimestamps.count >= minimumStrongPeaksForShake &&
            rmsEnergy >= minimumBurstRMS {
            peakTimestamps.removeAll(keepingCapacity: true)
            strongPeakTimestamps.removeAll(keepingCapacity: true)
            energySamples.removeAll(keepingCapacity: true)
            cooldownUntil = timestamp + cooldownSeconds
            return true
        }
        return false
    }

    private func magnitude(_ x: Double, _ y: Double, _ z: Double) -> Double {
        sqrt(x * x + y * y + z * z)
    }

    private func rootMeanSquare(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let meanSquare = values.reduce(0) { $0 + ($1 * $1) } / Double(values.count)
        return sqrt(meanSquare)
    }
}

