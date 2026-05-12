import Foundation
import Combine
import AVFoundation
import SwiftUI
import WebKit

enum SoundscapeMood: String, CaseIterable, Identifiable {
    case happy
    case neutral
    case sad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .happy:
            return "Happy"
        case .neutral:
            return "Neutral"
        case .sad:
            return "Sad"
        }
    }

    var systemImage: String {
        switch self {
        case .happy:
            return "sun.max.fill"
        case .neutral:
            return "circle.hexagongrid.fill"
        case .sad:
            return "moon.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .happy:
            return Color(red: 0.83, green: 0.66, blue: 0.26)
        case .neutral:
            return Color(red: 0.48, green: 0.67, blue: 0.48)
        case .sad:
            return Color(red: 0.36, green: 0.56, blue: 0.77)
        }
    }
}

final class SoundscapeWebController: NSObject, ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var activeLayers: [String] = []
    @Published private(set) var statusText = "No sources active"
    @Published private(set) var currentMood: SoundscapeMood = .neutral
    @Published private(set) var lastError = ""

    private weak var webView: WKWebView?
    private var pendingScripts: [String] = []
    private var players: [String: AVAudioPlayer] = [:]

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    func pageDidBecomeReady() {
        isReady = true
        flushPendingScripts()
        syncVisualization()
    }

    func updateState(activeSources: [String], mood: String?, statusText: String?) {
        if let mood, let resolvedMood = SoundscapeMood(rawValue: mood) {
            currentMood = resolvedMood
        }
        if let statusText, !statusText.isEmpty {
            self.statusText = statusText
        }
        if !activeSources.isEmpty {
            activeLayers = displayLayers(for: activeSources)
        }
    }

    func recordError(_ message: String) {
        lastError = message
        if !message.isEmpty {
            statusText = message
        }
    }

    func setMood(_ mood: SoundscapeMood) {
        currentMood = mood
        applyMoodToPlayers()
        syncVisualization()
    }

    func activateGesture(label: String) {
        switch label {
        case "bird":
            startSound(named: "birds")
        case "river":
            startSound(named: "river")
        default:
            break
        }
    }

    func reset() {
        for player in players.values {
            player.stop()
        }
        players.removeAll()
        activeLayers = []
        statusText = "No sources active"
        lastError = ""
        syncVisualization()
    }

    private func run(script: String) {
        guard let webView else {
            pendingScripts.append(script)
            return
        }
        guard isReady else {
            pendingScripts.append(script)
            return
        }
        webView.evaluateJavaScript(script)
    }

    private func flushPendingScripts() {
        guard let webView else { return }
        let scripts = pendingScripts
        pendingScripts.removeAll()
        for script in scripts {
            webView.evaluateJavaScript(script)
        }
    }

    private func startSound(named name: String) {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try player(for: name)
            player.volume = targetVolume(for: name)
            if !player.prepareToPlay() {
                throw NSError(domain: "Gesture2Audio.Sound", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to prepare \(name).wav for playback."
                ])
            }
            if !player.isPlaying {
                player.currentTime = 0
                guard player.play() else {
                    throw NSError(domain: "Gesture2Audio.Sound", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "AVAudioPlayer refused to start \(name).wav."
                    ])
                }
            }
            lastError = ""
            refreshPublishedState()
        } catch {
            recordError("Audio playback failed for \(name): \(error.localizedDescription)")
            refreshPublishedState()
        }
    }

    private func player(for name: String) throws -> AVAudioPlayer {
        if let existing = players[name] {
            applyMood(currentMood, to: existing, name: name)
            return existing
        }

        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            throw NSError(domain: "Gesture2Audio.Sound", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Bundled \(name).wav was not found."
            ])
        }

        let player = try AVAudioPlayer(contentsOf: url)
        player.numberOfLoops = -1
        player.enableRate = true
        applyMood(currentMood, to: player, name: name)
        players[name] = player
        return player
    }

    private func applyMoodToPlayers() {
        for (name, player) in players {
            applyMood(currentMood, to: player, name: name)
        }
        refreshPublishedState()
    }

    private func applyMood(_ mood: SoundscapeMood, to player: AVAudioPlayer, name: String) {
        switch mood {
        case .happy:
            player.rate = name == "birds" ? 1.22 : 1.12
            player.volume = name == "birds" ? 0.96 : 0.74
            player.pan = name == "birds" ? 0.22 : 0.10
        case .neutral:
            player.rate = 1.0
            player.volume = targetVolume(for: name)
            player.pan = 0
        case .sad:
            player.rate = name == "birds" ? 0.76 : 0.84
            player.volume = name == "birds" ? 0.46 : 0.52
            player.pan = name == "birds" ? -0.18 : -0.08
        }
    }

    private func targetVolume(for name: String) -> Float {
        switch name {
        case "birds":
            return 0.72
        case "river":
            return 0.58
        default:
            return 0.65
        }
    }

    private func refreshPublishedState() {
        let activeSourceNames = players.compactMap { key, player in
            player.isPlaying ? key : nil
        }.sorted()
        activeLayers = displayLayers(for: activeSourceNames)
        statusText = activeLayers.isEmpty ? "No sources active" : "\(activeLayers.joined(separator: " + ")) playing"
        syncVisualization()
    }

    private func displayLayers(for sourceNames: [String]) -> [String] {
        sourceNames.map {
            switch $0 {
            case "birds":
                return "Bird chirps"
            case "river":
                return "River sound"
            default:
                return $0.capitalized
            }
        }
    }

    private func syncVisualization() {
        let sourceNames = players.compactMap { key, player in
            player.isPlaying ? key : nil
        }.sorted()
        let payload: [String: Any] = [
            "mood": currentMood.rawValue,
            "activeSources": sourceNames,
            "statusText": statusText,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        run(script: "window.g2aNativeBridge && window.g2aNativeBridge.update(\(json));")
    }
}

struct SoundscapeWebView: UIViewRepresentable {
    @ObservedObject var controller: SoundscapeWebController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(context.coordinator, name: "soundscapeBridge")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        controller.attach(webView: webView)

        if let url = Bundle.main.url(forResource: "soundscape_embed", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        controller.attach(webView: uiView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let controller: SoundscapeWebController

        init(controller: SoundscapeWebController) {
            self.controller = controller
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("window.g2aNativeBridge && window.g2aNativeBridge.notifyReady && window.g2aNativeBridge.notifyReady();")
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "soundscapeBridge" else { return }
            guard let payload = message.body as? [String: Any],
                  let type = payload["type"] as? String else { return }

            if type == "ready" {
                controller.pageDidBecomeReady()
                return
            }

            if type == "state" {
                let activeSources = payload["activeSources"] as? [String] ?? []
                let mood = payload["mood"] as? String
                let statusText = payload["statusText"] as? String
                controller.updateState(activeSources: activeSources, mood: mood, statusText: statusText)
                return
            }

            if type == "error" {
                let message = payload["message"] as? String ?? "soundscape preview error"
                controller.recordError(message)
            }
        }
    }
}
