import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.settingsTab) {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
                .tag(SettingsTab.general)

            recordingTab
                .tabItem { Label("Recording", systemImage: "record.circle") }
                .tag(SettingsTab.recording)

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)

            HelpView()
                .tabItem { Label("Help", systemImage: "questionmark.circle") }
                .tag(SettingsTab.help)
        }
        .environment(\.locale, appState.language.locale)
        .frame(width: 680, height: 480)
        .padding(20)
        .preferredColorScheme(appState.appearance.colorScheme)
    }

    private var generalTab: some View {
        Form {
            Picker("Appearance", selection: $appState.appearance) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(LocalizedStringKey(mode.title)).tag(mode)
                }
            }

            Picker("Language", selection: $appState.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }

            Section {
                Text("Appearance and accent color follow macOS System Settings.")
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
            TextField("Interval (seconds)", text: $appState.intervalText)

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
                .foregroundStyle(.tint)
            Text("Key Recorder")
                .font(.title2.bold())
            Text("Privacy-focused keyboard measurement for macOS")
                .foregroundStyle(.secondary)
            Text("Version 1.1.0")
                .font(.caption)
            Link(destination: URL(string: "https://buymeacoffee.com/romainfrezier")!) {
                Label("Buy me a coffee", systemImage: "cup.and.saucer")
            }
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
                .frame(width: 120)
            Button("Detect…", action: capture)
        }
    }
}
