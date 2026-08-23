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
                configurationSection
                exportSection
                statusSection
                actionSection
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
                keyRow(
                    title: "Key 1",
                    nameBinding: $appState.key1Name,
                    keyBinding: $appState.key1Text,
                    defaultName: "Key 1",
                    defaultKey: "a",
                    capture: appState.captureKey1
                )

                Divider()

                keyRow(
                    title: "Key 2",
                    nameBinding: $appState.key2Name,
                    keyBinding: $appState.key2Text,
                    defaultName: "Key 2",
                    defaultKey: "b",
                    capture: appState.captureKey2
                )

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
                Text(appState.csvURL?.path ?? "No file selected. The app will use Downloads by default.")
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
                        .fill(appState.isRecording ? .red : .green)
                        .frame(width: 10, height: 10)

                    Text(appState.statusMessage)
                        .font(.headline)
                }

                if !appState.permissionMessage.isEmpty {
                    Text(appState.permissionMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if appState.isRecording {
                    HStack(spacing: 12) {
                        statusPill(
                            title: "Remaining",
                            value: "\(Int(ceil(appState.remainingTime))) s"
                        )

                        statusPill(
                            title: appState.key1Name,
                            value: "\(String(format: "%.2f", appState.liveKey1Duration)) s"
                        )

                        statusPill(
                            title: appState.key2Name,
                            value: "\(String(format: "%.2f", appState.liveKey2Duration)) s"
                        )
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

    func keyRow(
        title: String,
        nameBinding: Binding<String>,
        keyBinding: Binding<String>,
        defaultName: String,
        defaultKey: String,
        capture: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(title))
                .font(.headline)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Display name")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(defaultName, text: nameBinding)
                        .textFieldStyle(.roundedBorder)
                        .disabled(appState.isRecording)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Keyboard key")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField(defaultKey, text: keyBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 100)
                            .disabled(appState.isRecording)
                        Button("Detect") { capture() }
                            .disabled(appState.isRecording)
                    }
                }
            }
        }
    }

    func labeledField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
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

#Preview {
    ContentView()
        .environmentObject(AppState())
}
