import Foundation

enum SessionStatus: String {
    case completed
    case partial
    case imported
}

struct SessionMetadataDraft: Equatable {
    var title = ""
    var experimentID = ""
    var subject = ""
    var operatorName = ""
    var protocolName = ""
    var tags = ""
    var notes = ""
}

struct SessionEntry: Identifiable, Equatable {
    let id: String
    var title: String
    var experimentID: String
    var subject: String
    var operatorName: String
    var protocolName: String
    var tags: String
    var notes: String
    let status: SessionStatus
    let createdAt: Date
    let startedAt: Date?
    let endedAt: Date?
    let archiveRelativePath: String
    let key1Name: String
    let key2Name: String
    let duration: TimeInterval
    let interval: TimeInterval
    let checksum: String
    let archiveSize: Int64

    var metadataDraft: SessionMetadataDraft {
        SessionMetadataDraft(
            title: title,
            experimentID: experimentID,
            subject: subject,
            operatorName: operatorName,
            protocolName: protocolName,
            tags: tags,
            notes: notes
        )
    }
}

struct CSVPreview: Equatable {
    struct Row: Identifiable, Equatable {
        let id = UUID()
        let interval: String
        let key1Duration: Double
        let key2Duration: Double
    }

    let key1Name: String
    let key2Name: String
    let rows: [Row]
    let totalKey1: Double
    let totalKey2: Double
}
