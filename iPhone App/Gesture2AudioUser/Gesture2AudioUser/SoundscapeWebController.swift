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
    @Published private(set) var lastError = ""

    private weak var webView: WKWebView?
    private var pendingScripts: [String] = []
    private var assetURLScript = ""

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    func pageDidBecomeReady() {
        isReady = true
        if !assetURLScript.isEmpty {
            run(script: assetURLScript)
        }
        flushPendingScripts()
        primeAudio()
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
        if activeSources.isEmpty && lastError.isEmpty {
            self.statusText = "No sources active"
        }
    }

    func recordError(_ message: String) {
        lastError = message
        if !message.isEmpty {
            statusText = message
        }
    }

    func clearError() {
        lastError = ""
        if activeLayers.isEmpty {
            statusText = "No sources active"
        }
    }

    func setMood(_ mood: SoundscapeMood) {
        currentMood = mood
        primeAudio()
        clearError()
        run(script: "window.g2a && window.g2a.setMood('\(mood.rawValue)');")
    }

    func activateGesture(label: String) {
        primeAudio()
        clearError()
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
        clearError()
        run(script: "window.g2a && window.g2a.reset();")
    }

    func configureAssetURLs(birds: URL, river: URL) {
        let birdsPath = escapedJavaScriptString(birds.absoluteString)
        let riverPath = escapedJavaScriptString(river.absoluteString)
        assetURLScript = "window.g2aAssetURLs = { birds: '\(birdsPath)', river: '\(riverPath)' };"
        if isReady {
            run(script: assetURLScript)
        }
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

    private func primeAudio() {
        run(script: "window.g2a && window.g2a.primeAudio && window.g2a.primeAudio();")
    }

    private func escapedJavaScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}

final class BundleAudioSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let requestURL = urlSchemeTask.request.url ?? URL(string: "g2audio://app/missing")!
        let resourceName = requestURL.deletingPathExtension().lastPathComponent
        let pathExtension = requestURL.pathExtension
        let resourceExtension = pathExtension.isEmpty ? "wav" : pathExtension

        guard !resourceName.isEmpty,
              let resourceURL = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) else {
            let response = HTTPURLResponse(
                url: requestURL,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": "text/plain; charset=utf-8",
                    "Content-Length": "\(Data("missing audio resource".utf8).count)",
                    "Access-Control-Allow-Origin": "*",
                ]
            )!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(Data("missing audio resource".utf8))
            urlSchemeTask.didFinish()
            return
        }

        do {
            let data = try Data(contentsOf: resourceURL)
            let mimeType: String
            switch resourceExtension.lowercased() {
            case "wav":
                mimeType = "audio/wav"
            case "html":
                mimeType = "text/html; charset=utf-8"
            case "js":
                mimeType = "application/javascript; charset=utf-8"
            case "json":
                mimeType = "application/json; charset=utf-8"
            default:
                mimeType = "application/octet-stream"
            }
            let response = HTTPURLResponse(
                url: requestURL,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": mimeType,
                    "Content-Length": "\(data.count)",
                    "Access-Control-Allow-Origin": "*",
                    "Cache-Control": "no-cache",
                ]
            )!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
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
        configuration.setURLSchemeHandler(context.coordinator.assetHandler, forURLScheme: "g2audio")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        controller.attach(webView: webView)

        controller.configureAssetURLs(
            birds: URL(string: "g2audio://app/birds.wav")!,
            river: URL(string: "g2audio://app/river.wav")!
        )
        webView.load(URLRequest(url: URL(string: "g2audio://app/soundscape_embed.html")!))

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        controller.attach(webView: uiView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let controller: SoundscapeWebController
        let assetHandler = BundleAudioSchemeHandler()

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
                return
            }

            if type == "error" {
                let message = payload["message"] as? String ?? "sound engine error"
                controller.recordError(message)
            }
        }
    }
}
