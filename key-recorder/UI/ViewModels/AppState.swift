//
//  AppState.swift
//  key-recorder
//
//  Created by Romain on 24.03.2026.
//

import Foundation
import AppKit
import ApplicationServices
import UniformTypeIdentifiers

// Import Core module types - they are part of the same target

@MainActor
final class AppState: ObservableObject {
    @Published var key1Text: String = "a"
    @Published var key2Text: String = "b"
    @Published var key1Name: String = "Key 1"
    @Published var key2Name: String = "Key 2"
    @Published var durationText: String = "10"
    @Published var intervalText: String = "2"
    @Published var liveKey1Duration: TimeInterval = 0
    @Published var liveKey2Duration: TimeInterval = 0
    @Published var csvURL: URL?

    @Published var isRecording: Bool = false
    @Published var remainingTime: TimeInterval = 0
    @Published var statusMessage: String = "Ready"
    @Published var permissionMessage: String = ""

    private let monitor = KeyboardMonitor()
    private var session: RecordingSession?

    init() {
        monitor.onEvent = { [weak self] keyCode, isDown in
            guard let self else { return }
            self.session?.handleEvent(keyCode: keyCode, isDown: isDown)
        }
    }

    func preparePermissionsPromptIfNeeded() {
        let state = PermissionManager.shared.checkPermissions(promptIfNeeded: true)
        permissionMessage = state.message
    }

    func chooseSaveLocation() {
        let panel = NSSavePanel()
        panel.title = "Choose CSV destination"
        panel.message = "Select where to save the CSV file."
        panel.prompt = "Save"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = defaultFileName()
        panel.allowedContentTypes = [UTType.commaSeparatedText]

        if panel.runModal() == .OK, let url = panel.url {
            self.csvURL = url
        }
    }

    func startRecording() {
        guard !isRecording else { return }

        do {
            let config = try buildConfig()
            try ensurePermissions()

            let destinationURL = csvURL ?? defaultSaveURL()
            csvURL = destinationURL

            let newSession = RecordingSession(config: config, outputURL: destinationURL)
            self.session = newSession

            newSession.onTick = { [weak self] remaining in
                Task { @MainActor in
                    self?.remainingTime = remaining
                    self?.statusMessage = "Recording..."
                }
            }
            
            newSession.onLiveUpdate = { [weak self] key1Total, key2Total in
                Task { @MainActor in
                    self?.liveKey1Duration = key1Total
                    self?.liveKey2Duration = key2Total
                }
            }

            newSession.onFinished = { [weak self] result in
                Task { @MainActor in
                    self?.isRecording = false
                    self?.monitor.stop()
                    switch result {
                    case .success:
                        self?.remainingTime = 0
                        self?.liveKey1Duration = 0
                        self?.liveKey2Duration = 0
                        self?.statusMessage = "CSV exported successfully ✅"
                    case .failure(let error):
                        self?.remainingTime = 0
                        self?.liveKey1Duration = 0
                        self?.liveKey2Duration = 0
                        self?.statusMessage = "Export failed: \(error.localizedDescription)"
                    }
                }
            }

            try monitor.start()
            isRecording = true
            remainingTime = config.duration
            statusMessage = "Recording..."
            permissionMessage = "Permissions granted ✅"
            liveKey1Duration = 0
            liveKey2Duration = 0
            newSession.start()
        } catch {
            statusMessage = "Cannot start: \(error.localizedDescription)"
        }
    }

    private func buildConfig() throws -> RecordingConfig {
        guard let duration = TimeInterval(durationText), duration > 0 else {
            throw AppError.invalidDuration
        }

        guard let interval = TimeInterval(intervalText), interval > 0 else {
            throw AppError.invalidInterval
        }

        guard interval <= duration else {
            throw AppError.intervalGreaterThanDuration
        }

        guard let key1Code = KeyParser.keyCode(from: key1Text),
              let key2Code = KeyParser.keyCode(from: key2Text) else {
            throw AppError.invalidKey
        }

        return RecordingConfig(
            key1Name: key1Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Key 1" : key1Name,
            key2Name: key2Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Key 2" : key2Name,
            key1Display: key1Text,
            key2Display: key2Text,
            key1Code: key1Code,
            key2Code: key2Code,
            duration: duration,
            interval: interval
        )
    }

    private func ensurePermissions() throws {
        try PermissionManager.shared.ensureAllPermissions()
    }

    private func defaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "key-recording-\(formatter.string(from: Date())).csv"
    }

    private func defaultSaveURL() -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        return (downloads ?? FileManager.default.homeDirectoryForCurrentUser)
            .appendingPathComponent(defaultFileName())
    }
    
    func applyDurationPreset(_ value: Int) {
        guard !isRecording else { return }
        durationText = "\(value)"
    }

    func applyIntervalPreset(_ value: Int) {
        guard !isRecording else { return }
        intervalText = "\(value)"
    }
}
