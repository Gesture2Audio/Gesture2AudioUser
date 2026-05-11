//
//  GesturetoAudioApp.swift
//  GesturetoAudio
//
//  Created by ravishan_n on 25/2/2026.
//

import SwiftUI

@main
struct GesturetoAudioApp: App {
    @StateObject private var debugSession = PhoneDebugSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(debugSession)
        }
    }
}
