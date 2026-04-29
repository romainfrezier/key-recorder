//
//  AppDelegate.swift
//  key-recorder
//
//  Created by Romain on 24.03.2026.
//

import AppKit

// Import AppState from UI/ViewModels - part of same module

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState?.preparePermissionsPromptIfNeeded()
    }
}
