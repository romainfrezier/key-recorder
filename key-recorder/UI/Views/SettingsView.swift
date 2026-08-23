import SwiftUI

struct SettingsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case general, recording, about, help

        var id: String { rawValue }
        var title: String { rawValue.capitalized }

        var systemImage: String {
            switch self {
            case .general: return "gear"
            case .recording: return "record.circle"
            case .about: return "info.circle"
            case .help: return "questionmark.circle"
            }
        }
    }

    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .general

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ForEach(Tab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 24))
                            Text(tab.title)
                                .font(.callout)
                        }
                        .frame(width: 112, height: 68)
                        .foregroundStyle(selectedTab == tab ? appState.accentColor.color : .secondary)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(appState.accentColor.color.opacity(0.12))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)

            Divider()

            Group {
                switch selectedTab {
                case .general: generalTab
                case .recording: recordingTab
                case .about: aboutTab
                case .help: HelpView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 680, height: 480)
        .padding(20)
        .preferredColorScheme(appState.appearance.colorScheme)
        .tint(appState.accentColor.color)
        .accentColor(appState.accentColor.color)
    }

    private var generalTab: some View {
        Form {
            Picker("Appearance", selection: $appState.appearance) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            HStack {
                Text("Accent Color")
                Spacer()
                Menu {
                    ForEach(AccentColor.allCases) { color in
                        Button {
                            appState.accentColor = color
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(color.color)
                                    .font(.system(size: 10))
                                Text(color.title)
                                if color == appState.accentColor {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(appState.accentColor.color)
                            .font(.system(size: 10))
                        Text(appState.accentColor.title)
                    }
                }
            }

            Section {
                Text("Automatic follows the appearance selected in macOS System Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Reset Recording Settings") {
                appState.resetSettings()
            }
        }
        .formStyle(.grouped)
        .disabled(appState.isRecording)
    }

    private var recordingTab: some View {
        Form {
            TextField("Duration (seconds)", text: $appState.durationText)
                .accentTextField(appState.accentColor.color)
            TextField("Interval (seconds)", text: $appState.intervalText)
                .accentTextField(appState.accentColor.color)

            Text("These are the default values used when starting a new recording. You can change them here or before each observation.")
                .font(.caption)
                .foregroundStyle(.secondary)

            keySetting(title: "Key 1", name: $appState.key1Name, text: appState.key1Text) {
                appState.captureKey1()
            }
            keySetting(title: "Key 2", name: $appState.key2Name, text: appState.key2Text) {
                appState.captureKey2()
            }

            Text("The app records only the two configured keys and stores data locally.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 42))
                .foregroundStyle(appState.accentColor.color)
            Text("Key Recorder")
                .font(.title2.bold())
            Text("Privacy-focused keyboard measurement for macOS")
                .foregroundStyle(.secondary)
            Text("Version 1.1.0")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func keySetting(
        title: String,
        name: Binding<String>,
        text: String,
        capture: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                Text("Current key: \(text)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TextField("Name", text: name)
                .accentTextField(appState.accentColor.color)
                .frame(width: 120)
            Button("Detect…", action: capture)
        }
    }
}
