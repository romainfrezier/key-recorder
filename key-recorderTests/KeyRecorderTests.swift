import XCTest
@testable import key_recorder

@MainActor
final class KeyRecorderTests: XCTestCase {
    func testKeyParserSupportsKnownKeys() {
        XCTAssertEqual(KeyParser.keyCode(from: " a "), 0)
        XCTAssertEqual(KeyParser.keyCode(from: "SPACE"), 49)
        XCTAssertEqual(KeyParser.displayName(for: 0), "a")
    }

    func testCSVQuotesHeadersAndUsesStableDecimals() throws {
        let config = RecordingConfig(
            key1Name: "Mouse \"food\"",
            key2Name: "Lever",
            key1Display: "a",
            key2Display: "b",
            key1Code: 0,
            key2Code: 11,
            duration: 2,
            interval: 2
        )
        let start = Date(timeIntervalSince1970: 0)
        let records = [
            IntervalRecord(
                intervalStart: start,
                intervalEnd: start.addingTimeInterval(2),
                key1Duration: 1.25,
                key2Duration: 0.5
            )
        ]
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("csv")

        try CSVExporter.export(records: records, config: config, to: url)
        let csv = try String(contentsOf: url, encoding: .utf8)
        try FileManager.default.removeItem(at: url)

        XCTAssertTrue(csv.hasPrefix("interval,\"Mouse \"\"food\"\"\",Lever\n"))
        XCTAssertTrue(csv.contains("1.250,0.500"))
        XCTAssertTrue(csv.contains("TOTAL,1.250,0.500"))
    }

    func testCSVAddsExtensionWhenMissing() throws {
        let config = RecordingConfig(
            key1Name: "A",
            key2Name: "B",
            key1Display: "a",
            key2Display: "b",
            key1Code: 0,
            key2Code: 11,
            duration: 1,
            interval: 1
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try CSVExporter.export(records: [], config: config, to: url)
        let csvURL = url.appendingPathExtension("csv")
        XCTAssertTrue(FileManager.default.fileExists(atPath: csvURL.path))
        try FileManager.default.removeItem(at: csvURL)
    }

    func testSessionCatalogKeepsArchiveAndCanReexportAfterImport() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let sourceURL = root.appendingPathComponent("observation.csv")
        let csv = "interval,Food,Lever\n0s - 1s,0.500,0.000\n\nTOTAL,0.500,0.000\n"
        try Data(csv.utf8).write(to: sourceURL)

        do {
            let catalog = SessionCatalog(rootURL: root)
            let session = try catalog.importCSV(from: sourceURL)
            let archiveURL = catalog.archiveURL(for: session.id)
            XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))
            XCTAssertEqual(try catalog.preview(for: session).totalKey1, 0.5)

            let destination = root.appendingPathComponent("reexport.csv")
            _ = try catalog.export(session: session, to: destination)
            XCTAssertEqual(try Data(contentsOf: destination), try Data(contentsOf: archiveURL))

            try catalog.updateMetadata(
                for: session.id,
                draft: SessionMetadataDraft(title: "Mouse 01", subject: "Mouse 01")
            )
            catalog.refresh(search: "Mouse 01")
            XCTAssertEqual(catalog.sessions.first?.subject, "Mouse 01")

            do {
                let reopenedCatalog = SessionCatalog(rootURL: root)
                XCTAssertEqual(reopenedCatalog.sessions.first?.subject, "Mouse 01")
            }

            try catalog.removeFromCatalog(session)
            XCTAssertTrue(FileManager.default.fileExists(atPath: archiveURL.path))
        }

        try? FileManager.default.removeItem(at: root)
    }
}
