import SwiftUI
import AppKit

struct SessionDetailView: View {
    @EnvironmentObject private var appState: AppState
    let session: SessionEntry

    @State private var draft: SessionMetadataDraft
    @State private var preview: CSVPreview?
    @State private var showingRemoveConfirmation = false

    init(session: SessionEntry) {
        self.session = session
        _draft = State(initialValue: session.metadataDraft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    metadataSection
                    resultSection
                }
                .padding(24)
            }
        }
        .task(id: session.id) {
            preview = appState.preview(for: session)
        }
        .alert("Remove session from catalogue?", isPresented: $showingRemoveConfirmation) {
            Button("Remove", role: .destructive) {
                appState.removeSession(session)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The archived CSV will be kept safely in Key Recorder.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.title.isEmpty ? "Untitled session" : session.title)
                    .font(.title2.bold())
                Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge
        }
        .padding(24)
    }

    private var statusBadge: some View {
        Text(session.status.rawValue.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(session.status == .partial ? Color.orange.opacity(0.18) : Color.green.opacity(0.18))
            .clipShape(Capsule())
    }

    private var metadataSection: some View {
        GroupBox("Session details") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Title", text: $draft.title)
                    .accentTextField(appState.accentColor.color)
                TextField("Experiment ID", text: $draft.experimentID)
                    .accentTextField(appState.accentColor.color)
                TextField("Subject or sample", text: $draft.subject)
                    .accentTextField(appState.accentColor.color)
                TextField("Operator", text: $draft.operatorName)
                    .accentTextField(appState.accentColor.color)
                TextField("Protocol", text: $draft.protocolName)
                    .accentTextField(appState.accentColor.color)
                TextField("Tags", text: $draft.tags)
                    .accentTextField(appState.accentColor.color)
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)
                    .accentTextField(appState.accentColor.color)

                HStack {
                    Button("Save details") {
                        appState.updateMetadata(for: session, draft: draft)
                    }
                    Spacer()
                    Button("Remove from catalogue", role: .destructive) {
                        showingRemoveConfirmation = true
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var resultSection: some View {
        GroupBox("CSV result") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(appState.sessionCatalog.archiveIsCurrent(session) ? "Archived copy verified" : "Archive needs attention", systemImage: appState.sessionCatalog.archiveIsCurrent(session) ? "checkmark.shield" : "exclamationmark.triangle")
                        .foregroundStyle(appState.sessionCatalog.archiveIsCurrent(session) ? .green : .orange)
                    Spacer()
                    Button("Export CSV copy…") {
                        appState.exportSession(session)
                    }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([appState.sessionCatalog.archiveURL(for: session.id)])
                    }
                }

                if let preview {
                    Table(preview.rows) {
                        TableColumn("Interval") { row in Text(row.interval) }
                        TableColumn(preview.key1Name) { row in Text(row.key1Duration, format: .number.precision(.fractionLength(3))) }
                        TableColumn(preview.key2Name) { row in Text(row.key2Duration, format: .number.precision(.fractionLength(3))) }
                    }
                    .frame(minHeight: 180, maxHeight: 360)

                    HStack {
                        Text("TOTAL")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(preview.totalKey1, specifier: "%.3f") s")
                        Text("\(preview.totalKey2, specifier: "%.3f") s")
                    }
                    .font(.system(.body, design: .monospaced))
                } else {
                    Label("The archived CSV cannot be previewed.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }

                Text("Archive: \(appState.sessionCatalog.archiveURL(for: session.id).path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(.top, 6)
        }
    }
}
