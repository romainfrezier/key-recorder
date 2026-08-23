import SwiftUI

struct KeyRecorderCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandMenu("Recording") {
            Button("Start Recording") {
                appState.startRecording()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(appState.isRecording)

            Button("Stop Recording") {
                appState.stopRecording()
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(!appState.isRecording)

            Divider()

            Button("Choose CSV Location…") {
                appState.chooseSaveLocation()
            }

            Button("Open Last CSV") {
                appState.openLastCSV()
            }
            .disabled(!appState.canOpenLastCSV)
        }

        CommandGroup(replacing: .help) {
            Button("Key Recorder Help") {
                appState.openHelp()
            }
            .keyboardShortcut("/", modifiers: .command)
        }
    }
}
