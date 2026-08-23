import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                helpSection("Start an observation", systemImage: "play.circle") {
                    Text("Choose two event keys, give them meaningful names, set the duration and interval, then press Start Recording. Hold each key while its event is happening and release it when the event ends.")
                }

                helpSection("Permissions", systemImage: "lock.shield") {
                    Text("macOS asks for Accessibility and Input Monitoring so Key Recorder can receive the two selected keys outside its own window. The app records only those keys during an active session and keeps the CSV on this Mac.")
                }

                helpSection("Shortcuts", systemImage: "command") {
                    VStack(alignment: .leading, spacing: 6) {
                        shortcut("⌘R", "Start recording")
                        shortcut("⌘.", "Stop and export the partial session")
                        shortcut("⌘,", "Open Preferences")
                    }
                }

                helpSection("Understand the CSV", systemImage: "doc.text") {
                    Text("Each row is an analysis interval. Values are durations in seconds, not interaction counts. TOTAL adds the durations for each configured key. A filename ending in -partial means the observation was stopped before its planned duration.")
                }

                helpSection("For a research protocol", systemImage: "checklist") {
                    Text("Keep the experiment identifier, operator, subject or sample identifier, key definitions, duration, interval, and any interruption note with the exported CSV. Key Recorder stores measurements, not your experimental metadata.")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func helpSection<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(LocalizedStringKey(title), systemImage: systemImage)
                .font(.headline)
            content()
                .foregroundStyle(.secondary)
        }
    }

    private func shortcut(_ keys: String, _ description: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .frame(width: 46, alignment: .leading)
            Text(LocalizedStringKey(description))
        }
    }
}
