//
//  ContentView.swift
//  key-recorder
//
//  Created by Romain on 24.03.2026.
//

import SwiftUI

// Import AppState from UI/ViewModels - part of same target

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            sessionSidebar
        } detail: {
            if let selectedSession = appState.selectedSession {
                SessionDetailView(session: selectedSession)
            } else {
                recordingWorkspace
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Sections

private extension ContentView {
    var sessionSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                Button {
                    appState.importSession()
                } label: {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
                }
                .labelStyle(.iconOnly)
                .help("Import a CSV into the local archive")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            TextField("Search sessions", text: $appState.sessionSearchText)
                .textFieldStyle(.roundedBorder)
                .padding(12)

            List(selection: $appState.selectedSessionID) {
                ForEach(appState.sessions) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title.isEmpty ? "Untitled session" : session.title)
                            .lineLimit(1)
                        HStack {
                            Text(session.createdAt.formatted(date: .abbreviated, time: .omitted))
                            if !session.subject.isEmpty {
                                Text("• \(session.subject)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .tag(session.id)
                }
            }

            Divider()
            Button("New recording") {
                appState.selectedSessionID = nil
            }
            .padding(10)
        }
        .navigationSplitViewColumnWidth(min: 240, ideal: 280)
    }

    var recordingWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                if !appState.isRecording {
                    configurationSection
                    exportSection
                }
                statusSection
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionSection
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(.bar)
        }
    }

    var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Key Recorder")
                    .font(.system(size: 28, weight: .bold))

                Text("Record global keyboard activity and export the result to CSV.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button {
                    appState.openHelp()
                } label: {
                    Label("How to use Key Recorder", systemImage: "questionmark.circle")
                }
                .buttonStyle(.link)
                .foregroundStyle(Color(nsColor: .controlAccentColor))
                .pointingHandCursor()
            }

            Spacer()

            SettingsLink {
                Image(systemName: "gear")
                    .font(.title2)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color(nsColor: .controlAccentColor))
            .help("Settings")
            .pointingHandCursor()
        }
    }

    var configurationSection: some View {
        sectionCard(title: "Configuration", systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 16) {
                KeyConfigurationView()

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    labeledField("Duration (s)", text: $appState.durationText, placeholder: "10")

                    presetButtons([10, 30, 60, 120]) { value in
                        appState.applyDurationPreset(value)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    labeledField("Interval (s)", text: $appState.intervalText, placeholder: "2")

                    presetButtons([1, 2, 5, 10, 30]) { value in
                        appState.applyIntervalPreset(value)
                    }
                }
            }
        }
    }

    var exportSection: some View {
        sectionCard(title: "CSV Export", systemImage: "doc.text") {
            VStack(alignment: .leading, spacing: 12) {
                Text(appState.csvURL?.path ?? String(localized: "No file selected. The app will use Downloads by default.", locale: appState.language.locale))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    Task { @MainActor in
                        appState.chooseSaveLocation()
                    }
                } label: {
                    Label("Choose CSV Location", systemImage: "folder")
                }
                .disabled(appState.isRecording)
            }
        }
    }

    var statusSection: some View {
        sectionCard(title: "Status", systemImage: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(appState.isRecording ? .red : appState.hasInputMonitoringPermission ? .green : .orange)
                        .frame(width: 10, height: 10)

                    Text(appState.statusMessage)
                        .font(.headline)
                }

                if !appState.permissionMessage.isEmpty {
                    Text(appState.permissionMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if !appState.hasInputMonitoringPermission {
                        Button {
                            appState.openInputMonitoringSettings()
                        } label: {
                            Label("Open Input Monitoring Settings", systemImage: "gear")
                        }
                    }
                }

                if appState.isRecording {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], alignment: .leading, spacing: 12) {
                        statusPill(
                            title: String(localized: "Remaining", locale: appState.language.locale),
                            value: "\(Int(ceil(appState.remainingTime))) s"
                        )
                        ForEach(Array(appState.keys.enumerated()), id: \.element.id) { index, key in
                            statusPill(
                                title: key.name,
                                value: "\(String(format: "%.2f", appState.liveKeyDurations.indices.contains(index) ? appState.liveKeyDurations[index] : 0)) s"
                            )
                        }
                    }
                }
            }
        }
    }

    var actionSection: some View {
        HStack {
            Spacer()

            Button {
                if appState.isRecording {
                    appState.stopRecording()
                } else {
                    appState.startRecording()
                }
            } label: {
                Label(appState.isRecording ? "Stop Recording" : "Start Recording", systemImage: appState.isRecording ? "stop.circle" : "record.circle")
                    .font(.headline)
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.capturingKeyID != nil)
            .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Reusable UI

private extension ContentView {
    func sectionCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(LocalizedStringKey(title), systemImage: systemImage)
                .font(.headline)

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func labeledField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title))
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .disabled(appState.isRecording)
                .frame(maxWidth: 180)
        }
    }

    func presetButtons(_ values: [Int], action: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(values, id: \.self) { value in
                Button("\(value)s") {
                    action(value)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appState.isRecording)
            }
        }
    }

    func statusPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.body, design: .monospaced).weight(.semibold))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// The same editor is used before an observation and in Recording settings.
struct KeyConfigurationView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Event keys").font(.headline)
                Spacer()
                Text("\(appState.keys.count) / \(RecordingConfig.maximumKeys)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("\(appState.keys.count) keys configured"))
            }

            ForEach($appState.keys) { $key in
                HStack(spacing: 10) {
                    TextField("Display name", text: $key.name)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .accessibilityLabel("Display name")
                    TextField("Keyboard key", text: $key.text)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .frame(width: 90)
                        .accessibilityLabel("Keyboard key")
                    Button {
                        if appState.capturingKeyID == key.id {
                            appState.stopCapturingKey()
                        } else {
                            appState.captureKey(id: key.id)
                        }
                    } label: {
                        Text(appState.capturingKeyID == key.id ? "Cancel" : "Detect")
                            .frame(minWidth: 50)
                    }
                    Button {
                        appState.removeKey(id: key.id)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Remove key")
                    .accessibilityLabel(Text("Remove key: \(key.name)"))
                    .disabled(appState.keys.count == 1)
                }
            }

            HStack {
                Button {
                    appState.addKey()
                } label: {
                    Label("Add key", systemImage: "plus")
                }
                .disabled(appState.keys.count >= RecordingConfig.maximumKeys)
                Spacer()
                if appState.capturingKeyID != nil {
                    Text("Press a key to capture it...")
                        .foregroundStyle(.tint)
                } else {
                    Text("1 to 7 keys, recorded independently.")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
        .disabled(appState.isRecording)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
