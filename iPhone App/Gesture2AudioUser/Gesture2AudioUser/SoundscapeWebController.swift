import Foundation
import Combine
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

    private weak var webView: WKWebView?
    private var pendingScripts: [String] = []

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    func pageDidBecomeReady() {
        isReady = true
        flushPendingScripts()
        setMood(currentMood)
    }

    func updateState(activeSources: [String], mood: String?, statusText: String?) {
        activeLayers = activeSources.map {
            switch $0 {
            case "birds":
                return "Bird chirps"
            case "river":
                return "River sound"
            default:
                return $0.capitalized
            }
        }
        if let statusText, !statusText.isEmpty {
            self.statusText = statusText
        }
        if let mood, let resolvedMood = SoundscapeMood(rawValue: mood) {
            currentMood = resolvedMood
        }
    }

    func setMood(_ mood: SoundscapeMood) {
        currentMood = mood
        run(script: "window.g2a && window.g2a.setMood('\(mood.rawValue)');")
    }

    func activateGesture(label: String) {
        switch label {
        case "bird":
            run(script: "window.g2a && window.g2a.ensureSound('birds');")
        case "river":
            run(script: "window.g2a && window.g2a.ensureSound('river');")
        default:
            break
        }
    }

    func reset() {
        run(script: "window.g2a && window.g2a.reset();")
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
            webView.evaluateJavaScript("window.g2a && window.g2a.notifyReady && window.g2a.notifyReady();")
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
            }
        }
    }
}
