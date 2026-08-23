//
//  KeyRecorderApp.swift
//  key-recorder
//
//  Created by Romain on 24.03.2026.
//

import SwiftUI

// Import types from other parts of the same target

@main
struct KeyRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 520, minHeight: 420)
                .preferredColorScheme(appState.appearance.colorScheme)
                .onAppear {
                    appDelegate.appState = appState
                    appState.preparePermissionsPromptIfNeeded()
                }
        }
        .commands {
            KeyRecorderCommands(appState: appState)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .preferredColorScheme(appState.appearance.colorScheme)
        }
    }
}
