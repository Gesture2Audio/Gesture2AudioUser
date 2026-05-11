//
//  Gesture2AudioUserApp.swift
//  Gesture2AudioUser
//
//  Created by Nilesh Balapitiya Badugei on 11/5/2026.
//

import SwiftUI

@main
struct Gesture2AudioUserApp: App {
    @StateObject private var debugSession = PhoneDebugSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(debugSession)
        }
    }
}
