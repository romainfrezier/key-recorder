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
                TextField("Experiment ID", text: $draft.experimentID)
                TextField("Subject or sample", text: $draft.subject)
                TextField("Operator", text: $draft.operatorName)
                TextField("Protocol", text: $draft.protocolName)
                TextField("Tags", text: $draft.tags)
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)

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
                        TableColumnForEach(Array(preview.keyNames.indices), id: \.self) { index in
                            TableColumn(preview.keyNames[index]) { row in
                                Text(row.keyDurations[index], format: .number.precision(.fractionLength(3)))
                            }
                            .width(min: 100, ideal: 130)
                        }
                    }
                    .frame(minHeight: 180, maxHeight: 360)

                    Text("TOTAL").fontWeight(.semibold)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], alignment: .leading) {
                        ForEach(preview.keyNames.indices, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preview.keyNames[index]).font(.caption).foregroundStyle(.secondary)
                                Text("\(preview.totals[index], specifier: "%.3f") s")
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
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
