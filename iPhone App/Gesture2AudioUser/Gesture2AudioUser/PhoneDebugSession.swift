//
//  PhoneDebugSession.swift
//  Gesture2AudioUser
//
//  Created by Nilesh Balapitiya Badugei on 11/5/2026.
//

import Foundation
import WatchConnectivity
import Combine

struct PhoneDebugSnapshot {
    var label = "leaf"
    var sourceGesture = "leaf"
    var soundHint = "rustling_leaves"
    var statusMessage = ""
    var shakeDetected = false
    var shakeCount = 0
    var captureRemaining = 0.0
    var captureProgress = 0.0
    var captureState = "Shake to start"
    var savedCount = 0
    var ax = 0.0
    var ay = 0.0
    var az = 0.0
    var gx = 0.0
    var gy = 0.0
    var gz = 0.0
    var roll = 0.0
    var pitch = 0.0
    var yaw = 0.0
}

final class PhoneDebugSession: NSObject, ObservableObject, WCSessionDelegate {
    @Published var latest = PhoneDebugSnapshot()
    @Published var logs: [String] = []
    @Published var isReachable = false
    @Published var isDirectlyReachable = false
    @Published var selectedLabel = "leaf"
    @Published var selectedDay = 1
    @Published var savedByLabel: [String: Int] = [:]
    @Published var storageRootPath = ""
    @Published var lastStorageStatus = "research mode off"
    @Published var captureFilePath = ""
    @Published var classifierStatus = "loading model"
    @Published var lastPrediction: GesturePrediction?
    @Published var predictionHistory: [GesturePrediction] = []
    @Published var activeSoundLayers: [String] = []
    @Published var isAudioEnabled = true
    @Published var isResearchModeEnabled = false {
        didSet {
            if isResearchModeEnabled {
                bootstrapStorage()
            } else {
                captureFilePath = ""
                lastStorageStatus = "research mode off"
                pushLog("phone capture storage disabled")
            }
        }
    }

    let labels = ["leaf", "tree", "bird", "ocean", "river", "rain"]

    private let classifier = GestureClassifier()
    private let soundscape = SoundscapeEngine()
    private let maxLogLines = 120
    private let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
    private let watchActivityGracePeriod: TimeInterval = 4.0
    private var lastWatchActivityAt: Date?
    private var watchActivityExpiryWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        classifierStatus = classifier.loadStatus.displayText
        activate()
    }

    func chooseLabel(_ label: String) {
        guard labels.contains(label) else { return }
        selectedLabel = label
        updateWatchApplicationContext()
    }

    func chooseDay(_ day: Int) {
        let bounded = max(1, min(2, day))
        selectedDay = bounded
        updateWatchApplicationContext()
    }

    func resetSoundscape() {
        soundscape.reset()
        activeSoundLayers = []
        lastPrediction = nil
        predictionHistory.removeAll()
        pushLog("soundscape reset")
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func updateWatchApplicationContext() {
        guard WCSession.isSupported() else { return }
        do {
            try WCSession.default.updateApplicationContext([
                "selected_label": selectedLabel,
                "selected_day": selectedDay,
            ])
            pushLog("selection -> day_0\(selectedDay), \(selectedLabel)")
        } catch {
            pushLog("selection sync failed: \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.setDirectReachability(session.isReachable)
            if let error {
                self.pushLog("activation error: \(error.localizedDescription)")
            } else {
                self.pushLog("session activated")
                self.updateWatchApplicationContext()
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.setDirectReachability(false)
            self.pushLog("session inactive")
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        DispatchQueue.main.async {
            self.pushLog("session deactivated, reactivating")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.setDirectReachability(session.isReachable)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.recordWatchActivity()
            self.consume(payload: message)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async {
            self.recordWatchActivity()
            self.consume(payload: userInfo)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.recordWatchActivity()
            self.consume(payload: applicationContext)
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        DispatchQueue.main.async {
            self.recordWatchActivity()
        }
        processTransferredCapture(file)
    }

    private func consume(payload: [String: Any]) {
        let activeLabel = stringValue(payload["label"], fallback: latest.label)
        latest.label = activeLabel
        if labels.contains(activeLabel) {
            selectedLabel = activeLabel
        }
        selectedDay = intValue(payload["day"], fallback: selectedDay)
        latest.sourceGesture = stringValue(payload["source_gesture"], fallback: latest.sourceGesture)
        latest.soundHint = stringValue(payload["sound_hint"], fallback: latest.soundHint)
        latest.statusMessage = stringValue(payload["status_message"], fallback: latest.statusMessage)
        latest.shakeDetected = boolValue(payload["shake_detected"], fallback: latest.shakeDetected)
        latest.shakeCount = intValue(payload["shake_count"], fallback: latest.shakeCount)
        latest.captureRemaining = doubleValue(payload["capture_remaining"], fallback: latest.captureRemaining)
        latest.captureProgress = doubleValue(payload["capture_progress"], fallback: latest.captureProgress)
        latest.captureState = stringValue(payload["capture_state"], fallback: latest.captureState)
        latest.savedCount = intValue(payload["saved_count"], fallback: latest.savedCount)
        latest.ax = doubleValue(payload["ax"], fallback: latest.ax)
        latest.ay = doubleValue(payload["ay"], fallback: latest.ay)
        latest.az = doubleValue(payload["az"], fallback: latest.az)
        latest.gx = doubleValue(payload["gx"], fallback: latest.gx)
        latest.gy = doubleValue(payload["gy"], fallback: latest.gy)
        latest.gz = doubleValue(payload["gz"], fallback: latest.gz)
        latest.roll = doubleValue(payload["roll"], fallback: latest.roll)
        latest.pitch = doubleValue(payload["pitch"], fallback: latest.pitch)
        latest.yaw = doubleValue(payload["yaw"], fallback: latest.yaw)
    }

    private func processTransferredCapture(_ sessionFile: WCSessionFile) {
        let day = intValue(sessionFile.metadata?["day"], fallback: selectedDay)
        let label = stringValue(sessionFile.metadata?["label"], fallback: "unknown")
        let sampleId = stringValue(sessionFile.metadata?["sample_id"], fallback: UUID().uuidString)
        let shouldPersist = isResearchModeEnabled

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let classificationURL: URL
                if shouldPersist {
                    let destination = try self.destinationURL(for: sessionFile.fileURL, day: day, label: label, sampleId: sampleId)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: sessionFile.fileURL, to: destination)
                    classificationURL = destination
                } else {
                    classificationURL = sessionFile.fileURL
                }

                let data = try Data(contentsOf: classificationURL)
                let recording = try JSONDecoder().decode(GestureRecording.self, from: data)

                guard let prediction = self.classifier.classify(frames: recording.frames) else {
                    DispatchQueue.main.async {
                        self.pushLog("classification skipped: model not ready")
                    }
                    return
                }

                DispatchQueue.main.async {
                    if shouldPersist {
                        self.captureFilePath = classificationURL.path
                        self.savedByLabel[label, default: 0] += 1
                        self.pushLog("saved \(classificationURL.lastPathComponent)")
                    } else {
                        self.captureFilePath = ""
                        self.pushLog("processed transient capture \(sampleId.prefix(8))")
                    }

                    self.lastPrediction = prediction
                    self.predictionHistory.insert(prediction, at: 0)
                    if self.predictionHistory.count > 12 {
                        self.predictionHistory.removeLast(self.predictionHistory.count - 12)
                    }

                    if self.isAudioEnabled {
                        self.soundscape.activate(label: prediction.label)
                        self.activeSoundLayers = self.soundscape.activeLayers
                    }

                    let confidence = Int(round(prediction.confidence * 100))
                    self.pushLog("classified \(prediction.displayName) (\(confidence)%)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.pushLog(shouldPersist ? "save/classification failed: \(error.localizedDescription)" : "classification failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func bootstrapStorage() {
        do {
            let root = try storageRootDirectory()
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            storageRootPath = root.path
            captureFilePath = ""

            let marker = root.appendingPathComponent("README.txt")
            if !FileManager.default.fileExists(atPath: marker.path) {
                let content = """
                GesturetoAudio dataset root.
                This folder is auto-created by the app.
                Captures are stored day-wise with timestamp_day_class file names.
                """
                if let data = content.data(using: .utf8) {
                    try data.write(to: marker, options: .atomic)
                }
            }

            for day in 1...2 {
                _ = try ensureDayDirectory(day: day)
            }
            lastStorageStatus = "storage ready"
            pushLog("storage ready")
        } catch {
            lastStorageStatus = "storage init failed"
            pushLog("storage init failed: \(error.localizedDescription)")
        }
    }

    private func storageRootDirectory() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("GesturetoAudio", isDirectory: true)
    }

    private func ensureDayDirectory(day: Int) throws -> URL {
        let folderName = String(format: "day_%02d", max(1, min(2, day)))
        let dir = try storageRootDirectory().appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func destinationURL(for sourceURL: URL, day: Int, label: String, sampleId: String) throws -> URL {
        let dayFolder = try ensureDayDirectory(day: day)
        let timestamp = fileNameDateFormatter.string(from: Date())
        let safeLabel = sanitizedComponent(label)
        let shortId = String(sampleId.replacingOccurrences(of: "-", with: "").prefix(8))
        let fileName = "\(timestamp)_day_0\(max(1, min(2, day)))_\(safeLabel)_\(shortId).json"
        let destination = dayFolder.appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw NSError(domain: "GesturetoAudio.Storage", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Transferred capture file was missing."
            ])
        }

        return destination
    }

    private func sanitizedComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let raw = value.lowercased().replacingOccurrences(of: " ", with: "_")
        let scalars = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let sanitized = String(scalars)
        return sanitized.isEmpty ? "unknown" : sanitized
    }

    private func pushLog(_ message: String) {
        logs.insert(message, at: 0)
        if logs.count > maxLogLines {
            logs.removeLast(logs.count - maxLogLines)
        }
    }

    private func setDirectReachability(_ reachable: Bool) {
        isDirectlyReachable = reachable
        refreshWatchAvailability()
    }

    private func recordWatchActivity() {
        lastWatchActivityAt = Date()
        refreshWatchAvailability()

        watchActivityExpiryWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refreshWatchAvailability()
        }
        watchActivityExpiryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + watchActivityGracePeriod, execute: work)
    }

    private func refreshWatchAvailability() {
        let hasRecentActivity: Bool
        if let lastWatchActivityAt {
            hasRecentActivity = Date().timeIntervalSince(lastWatchActivityAt) < watchActivityGracePeriod
        } else {
            hasRecentActivity = false
        }
        isReachable = isDirectlyReachable || hasRecentActivity
    }

    private func stringValue(_ any: Any?, fallback: String) -> String {
        if let value = any as? String {
            return value
        }
        if let value = any {
            return String(describing: value)
        }
        return fallback
    }

    private func boolValue(_ any: Any?, fallback: Bool) -> Bool {
        if let value = any as? Bool {
            return value
        }
        if let value = any as? NSNumber {
            return value.boolValue
        }
        return fallback
    }

    private func intValue(_ any: Any?, fallback: Int) -> Int {
        if let value = any as? Int {
            return value
        }
        if let value = any as? NSNumber {
            return value.intValue
        }
        return fallback
    }

    private func doubleValue(_ any: Any?, fallback: Double) -> Double {
        if let value = any as? Double {
            return value
        }
        if let value = any as? NSNumber {
            return value.doubleValue
        }
        return fallback
    }
}
