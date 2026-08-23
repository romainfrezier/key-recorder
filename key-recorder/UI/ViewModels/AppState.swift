//
//  AppState.swift
//  key-recorder
//
//  Created by Romain on 24.03.2026.
//

import Foundation
import AppKit
import UniformTypeIdentifiers
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Automatic"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"
    case italian = "it"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        case .italian: return "Italiano"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    static var systemDefault: AppLanguage {
        for identifier in Locale.preferredLanguages {
            let languageCode = identifier.split(separator: "-").first.map(String.init) ?? identifier
            if let language = AppLanguage(rawValue: languageCode) {
                return language
            }
        }
        return .english
    }
}

enum SettingsTab: String, Hashable {
    case general
    case recording
    case about
    case help
}

struct PointingHandCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension View {
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursorModifier())
    }
}


// Import Core module types - they are part of the same target

@MainActor
final class AppState: ObservableObject {
    @Published var key1Text: String = "a" {
        didSet {
            if key1Text != oldValue {
                key1CapturedCode = nil
                if !isLoadingSettings {
                    defaults.removeObject(forKey: DefaultsKey.key1Code)
                }
            }
            persist()
        }
    }
    @Published var key2Text: String = "b" {
        didSet {
            if key2Text != oldValue {
                key2CapturedCode = nil
                if !isLoadingSettings {
                    defaults.removeObject(forKey: DefaultsKey.key2Code)
                }
            }
            persist()
        }
    }
    @Published var key1Name: String = "Key 1" { didSet { persist() } }
    @Published var key2Name: String = "Key 2" { didSet { persist() } }
    @Published var durationText: String = "10" { didSet { persist() } }
    @Published var intervalText: String = "2" { didSet { persist() } }
    @Published var appearance: AppearanceMode = .system { didSet { persist() } }
    @Published var language: AppLanguage = .english { didSet { persist() } }
    @Published var settingsTab: SettingsTab = .general
    @Published var liveKey1Duration: TimeInterval = 0
    @Published var liveKey2Duration: TimeInterval = 0
    @Published var csvURL: URL?

    @Published var isRecording: Bool = false
    @Published var remainingTime: TimeInterval = 0
    @Published var statusMessage: String = "Ready"
    @Published var permissionMessage: String = ""
    @Published var hasInputMonitoringPermission = false
    @Published var sessions: [SessionEntry] = []
    @Published var selectedSessionID: String?
    @Published var sessionSearchText = "" {
        didSet { refreshSessions() }
    }

    private let monitor = KeyboardMonitor()
    let sessionCatalog: SessionCatalog
    private var session: RecordingSession?
    private var activeSessionID: String?
    private var activeSessionStartedAt: Date?
    private var activeSessionConfig: RecordingConfig?
    private var activeExportURL: URL?
    private var capturingKeyTarget: Int?
    private var key1CapturedCode: CGKeyCode?
    private var key2CapturedCode: CGKeyCode?
    private var isLoadingSettings = true

    private let defaults = UserDefaults.standard

    private enum DefaultsKey {
        static let key1Text = "key1Text"
        static let key2Text = "key2Text"
        static let key1Name = "key1Name"
        static let key2Name = "key2Name"
        static let duration = "duration"
        static let interval = "interval"
        static let appearance = "appearance"
        static let language = "language"
        static let csvURL = "csvURL"
        static let key1Code = "key1Code"
        static let key2Code = "key2Code"
    }

    init() {
        sessionCatalog = SessionCatalog()
        sessions = sessionCatalog.sessions
        key1Text = defaults.string(forKey: DefaultsKey.key1Text) ?? key1Text
        key2Text = defaults.string(forKey: DefaultsKey.key2Text) ?? key2Text
        key1Name = defaults.string(forKey: DefaultsKey.key1Name) ?? key1Name
        key2Name = defaults.string(forKey: DefaultsKey.key2Name) ?? key2Name
        durationText = defaults.string(forKey: DefaultsKey.duration) ?? durationText
        intervalText = defaults.string(forKey: DefaultsKey.interval) ?? intervalText
        if let rawAppearance = defaults.string(forKey: DefaultsKey.appearance) {
            appearance = AppearanceMode(rawValue: rawAppearance) ?? .system
        }
        language = AppLanguage(
            rawValue: defaults.string(forKey: DefaultsKey.language) ?? ""
        ) ?? AppLanguage.systemDefault
        if let savedURL = defaults.url(forKey: DefaultsKey.csvURL) {
            csvURL = savedURL
        }
        if let code = defaults.object(forKey: DefaultsKey.key1Code) as? NSNumber {
            key1CapturedCode = CGKeyCode(code.uint16Value)
        }
        if let code = defaults.object(forKey: DefaultsKey.key2Code) as? NSNumber {
            key2CapturedCode = CGKeyCode(code.uint16Value)
        }

        monitor.onEvent = { [weak self] keyCode, isDown in
            Task { @MainActor [weak self] in
                self?.receiveEvent(keyCode: keyCode, isDown: isDown)
            }
        }
        statusMessage = localized("Ready")
        isLoadingSettings = false
    }

    var selectedSession: SessionEntry? {
        guard let selectedSessionID else { return nil }
        return sessions.first(where: { $0.id == selectedSessionID })
    }

    func preparePermissionsPromptIfNeeded() {
        let state = PermissionManager.shared.checkPermissions(promptIfNeeded: true)
        updatePermissionState(state)
    }

    func refreshPermissions() {
        let state = PermissionManager.shared.checkPermissions(promptIfNeeded: false)
        updatePermissionState(state)
    }

    func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }

    func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func openHelp() {
        settingsTab = .help
        openSettings()
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
            defaults.set(url, forKey: DefaultsKey.csvURL)
        }
    }

    func openLastCSV() {
        guard let csvURL else { return }
        NSWorkspace.shared.open(csvURL)
    }

    func refreshSessions() {
        sessionCatalog.refresh(search: sessionSearchText)
        sessions = sessionCatalog.sessions
        if let selectedSessionID, !sessions.contains(where: { $0.id == selectedSessionID }) {
            self.selectedSessionID = nil
        }
    }

    func importSession() {
        let panel = NSOpenPanel()
        panel.title = "Import CSV Session"
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let session = try sessionCatalog.importCSV(from: url)
            refreshSessions()
            selectedSessionID = session.id
            statusMessage = "CSV imported successfully ✅"
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    func preview(for session: SessionEntry) -> CSVPreview? {
        try? sessionCatalog.preview(for: session)
    }

    func exportSession(_ session: SessionEntry) {
        let panel = NSSavePanel()
        panel.title = "Export CSV Copy"
        panel.prompt = "Export"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(session.title.isEmpty ? session.id : session.title).csv"
        panel.allowedContentTypes = [UTType.commaSeparatedText]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let exportedURL = try sessionCatalog.export(session: session, to: url)
            csvURL = exportedURL
            statusMessage = "CSV copy exported successfully ✅"
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func updateMetadata(for session: SessionEntry, draft: SessionMetadataDraft) {
        do {
            try sessionCatalog.updateMetadata(for: session.id, draft: draft)
            refreshSessions()
            statusMessage = "Session details saved ✅"
        } catch {
            statusMessage = "Could not save session details: \(error.localizedDescription)"
        }
    }

    func removeSession(_ session: SessionEntry) {
        do {
            try sessionCatalog.removeFromCatalog(session)
            refreshSessions()
            statusMessage = "Session removed from the catalogue. Its archive is still safe."
        } catch {
            statusMessage = "Could not remove session: \(error.localizedDescription)"
        }
    }

    func captureKey1() { beginKeyCapture(target: 1) }

    func captureKey2() { beginKeyCapture(target: 2) }

    func stopCapturingKey() {
        capturingKeyTarget = nil
        monitor.stop()
        statusMessage = "Ready"
    }

    func startRecording() {
        guard !isRecording, capturingKeyTarget == nil else { return }

        do {
            let config = try buildConfig()
            try ensurePermissions()

            let destinationURL = csvURL ?? defaultSaveURL()
            let sessionID = sessionCatalog.newSessionID()
            let archiveURL = sessionCatalog.archiveURL(for: sessionID)
            let startedAt = Date()

            let newSession = RecordingSession(config: config, outputURL: archiveURL)
            self.session = newSession
            activeSessionID = sessionID
            activeSessionStartedAt = startedAt
            activeSessionConfig = config
            activeExportURL = destinationURL

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
                self?.handleSessionFinished(result)
            }

            try monitor.start()
            isRecording = true
            remainingTime = config.duration
            statusMessage = "Recording..."
            permissionMessage = localized("Permissions granted ✅")
            liveKey1Duration = 0
            liveKey2Duration = 0
            newSession.start()
        } catch {
            statusMessage = String(format: localized("Cannot start: %@"), localizedErrorMessage(error))
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        session?.stop()
    }

    var canOpenLastCSV: Bool { csvURL != nil && !isRecording }

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

        guard let key1Code = key1CapturedCode ?? KeyParser.keyCode(from: key1Text),
              let key2Code = key2CapturedCode ?? KeyParser.keyCode(from: key2Text) else {
            throw AppError.invalidKey
        }

        guard key1Code != key2Code else {
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

    private func beginKeyCapture(target: Int) {
        guard !isRecording else { return }
        do {
            try ensurePermissions()
            capturingKeyTarget = target
            statusMessage = "Press a key to capture it..."
            try monitor.start()
        } catch {
            capturingKeyTarget = nil
            statusMessage = String(format: localized("Cannot capture key: %@"), localizedErrorMessage(error))
        }
    }

    private func handleSessionFinished(_ result: Result<URL, Error>) {
        isRecording = false
        monitor.stop()
        remainingTime = 0
        liveKey1Duration = 0
        liveKey2Duration = 0

        guard let sessionID = activeSessionID,
              let config = activeSessionConfig,
              let startedAt = activeSessionStartedAt else {
            statusMessage = "Recording finished without session metadata."
            return
        }

        switch result {
        case .success(let stagingURL):
            do {
                let archiveURL = try sessionCatalog.archiveCSV(from: stagingURL, for: sessionID)
                let status: SessionStatus = stagingURL.lastPathComponent.contains("-partial") ? .partial : .completed
                let title = activeExportURL?.deletingPathExtension().lastPathComponent
                    ?? "Session \(sessionID.prefix(8))"
                let entry = try sessionCatalog.register(
                    id: sessionID,
                    status: status,
                    startedAt: startedAt,
                    endedAt: Date(),
                    config: config,
                    archiveURL: archiveURL,
                    draft: SessionMetadataDraft(title: title)
                )

                refreshSessions()
                selectedSessionID = entry.id

                if let activeExportURL {
                    do {
                        csvURL = try sessionCatalog.export(session: entry, to: activeExportURL)
                        statusMessage = status == .partial
                            ? "Partial CSV archived and exported ⚠️"
                            : "CSV archived and exported successfully ✅"
                    } catch {
                        statusMessage = "CSV archived safely, but the external copy failed: \(error.localizedDescription)"
                    }
                } else {
                    statusMessage = "CSV archived successfully ✅"
                }
            } catch {
                statusMessage = "CSV archive failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            statusMessage = "Recording failed: \(error.localizedDescription)"
        }

        session = nil
        self.activeSessionID = nil
        activeSessionStartedAt = nil
        activeSessionConfig = nil
        activeExportURL = nil
    }

    private func receiveEvent(keyCode: CGKeyCode, isDown: Bool) {
        if let target = capturingKeyTarget, isDown {
            capturingKeyTarget = nil
            let displayName = KeyParser.displayName(for: keyCode)
            if target == 1 {
                key1Text = displayName
                key1CapturedCode = keyCode
                defaults.set(Int(keyCode), forKey: DefaultsKey.key1Code)
            } else {
                key2Text = displayName
                key2CapturedCode = keyCode
                defaults.set(Int(keyCode), forKey: DefaultsKey.key2Code)
            }
            monitor.stop()
            statusMessage = "Key captured: \(displayName)"
            return
        }

        session?.handleEvent(keyCode: keyCode, isDown: isDown)
    }

    private func persist() {
        defaults.set(key1Text, forKey: DefaultsKey.key1Text)
        defaults.set(key2Text, forKey: DefaultsKey.key2Text)
        defaults.set(key1Name, forKey: DefaultsKey.key1Name)
        defaults.set(key2Name, forKey: DefaultsKey.key2Name)
        defaults.set(durationText, forKey: DefaultsKey.duration)
        defaults.set(intervalText, forKey: DefaultsKey.interval)
        defaults.set(appearance.rawValue, forKey: DefaultsKey.appearance)
    }

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), locale: language.locale)
    }

    private func localizedErrorMessage(_ error: Error) -> String {
        if let appError = error as? AppError {
            return localized(appError.localizationKey)
        }
        if let monitorError = error as? MonitorError {
            return localized(monitorError.localizationKey)
        }
        return localized(error.localizedDescription)
    }

    private func localizedPermissionMessage(_ state: PermissionState) -> String {
        if state.allGranted {
            return localized("Permissions look good ✅")
        }

        var missing: [String] = []
        if state.inputMonitoring != .granted {
            missing.append(localized("Input Monitoring"))
        }

        let format = localized("Grant %@ permissions in System Settings > Privacy & Security.")
        return String(format: format, missing.joined(separator: localized(" and ")))
    }

    private func updatePermissionState(_ state: PermissionState) {
        hasInputMonitoringPermission = state.inputMonitoring == .granted
        permissionMessage = localizedPermissionMessage(state)
    }
    
    func applyDurationPreset(_ value: Int) {
        guard !isRecording else { return }
        durationText = "\(value)"
    }

    func applyIntervalPreset(_ value: Int) {
        guard !isRecording else { return }
        intervalText = "\(value)"
    }

    func resetSettings() {
        guard !isRecording else { return }
        key1Text = "a"
        key2Text = "b"
        key1Name = "Key 1"
        key2Name = "Key 2"
        durationText = "10"
        intervalText = "2"
        appearance = .system
        csvURL = nil
        key1CapturedCode = nil
        key2CapturedCode = nil
        defaults.removeObject(forKey: DefaultsKey.csvURL)
        defaults.removeObject(forKey: DefaultsKey.key1Code)
        defaults.removeObject(forKey: DefaultsKey.key2Code)
    }
}
