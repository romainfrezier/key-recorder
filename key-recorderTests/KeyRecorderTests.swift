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
        let config = try RecordingConfig(
            definitions: [KeyDefinition(name: "Mouse \"food\"", text: "a"), KeyDefinition(name: "Lever", text: "b")],
            duration: 2,
            interval: 2
        )
        let start = Date(timeIntervalSince1970: 0)
        let records = [
            IntervalRecord(
                intervalStart: start,
                intervalEnd: start.addingTimeInterval(2),
                keyDurations: [1.25, 0.5]
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
        let config = try RecordingConfig(
            definitions: KeyDefinition.defaults,
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
            XCTAssertEqual(try catalog.preview(for: session).totals, [0.5, 0])

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

    func testOneThroughSevenKeysRoundTripThroughArchive() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let catalog = SessionCatalog(rootURL: root)
        for count in 1...7 {
            let definitions = (0..<count).map {
                KeyDefinition(name: "Event, \($0)\n\"label\"", text: "", capturedCode: UInt16($0))
            }
            let config = try RecordingConfig(definitions: definitions, duration: 2, interval: 2)
            let values = (0..<count).map { Double($0) / 10 }
            let url = root.appendingPathComponent("input-\(count).csv")
            let start = Date(timeIntervalSince1970: 0)
            try CSVExporter.export(records: [IntervalRecord(
                intervalStart: start, intervalEnd: start.addingTimeInterval(2), keyDurations: values
            )], config: config, to: url)
            let entry = try catalog.importCSV(from: url)
            let reopened = SessionCatalog(rootURL: root)
            let preview = try reopened.preview(for: entry)
            XCTAssertEqual(preview.keyNames, definitions.map(\.name))
            XCTAssertEqual(preview.rows.first?.keyDurations, values)
            XCTAssertEqual(preview.totals, values)
            let copy = root.appendingPathComponent("copy-\(count).csv")
            _ = try reopened.export(session: entry, to: copy)
            XCTAssertEqual(try Data(contentsOf: url), try Data(contentsOf: copy))
        }
    }

    func testSevenSimultaneousKeysAcrossIntervalsAndPartialStop() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let definitions = (0..<7).map { KeyDefinition(name: "Event \($0)", text: "", capturedCode: UInt16($0)) }
        let config = try RecordingConfig(definitions: definitions, duration: 5, interval: 2)
        for partial in [false, true] {
            let session = RecordingSession(config: config, outputURL: root.appendingPathComponent("session.csv"))
            var result: Result<URL, Error>?
            var live: [Double] = []
            var completions = 0
            session.onFinished = { result = $0; completions += 1 }
            session.onLiveUpdate = { live = $0 }
            let start = Date(timeIntervalSince1970: 0)
            session.start(at: start)
            session.handleEvent(keyCode: 0, isDown: true, at: start.addingTimeInterval(-1))
            for code in 0..<7 {
                session.handleEvent(keyCode: UInt16(code), isDown: true, at: start.addingTimeInterval(0.5))
                session.handleEvent(keyCode: UInt16(code), isDown: true, at: start.addingTimeInterval(1))
            }
            session.handleEvent(keyCode: 99, isDown: true, at: start.addingTimeInterval(1))
            session.handleEvent(keyCode: 0, isDown: false, at: start.addingTimeInterval(2.5))
            session.handleEvent(keyCode: 0, isDown: false, at: start.addingTimeInterval(2.75))
            session.tick(at: start.addingTimeInterval(3))
            XCTAssertEqual(live, [2] + Array(repeating: 2.5, count: 6))
            if partial { session.stop(at: start.addingTimeInterval(3)) }
            else { session.tick(at: start.addingTimeInterval(6)) }
            let url = try XCTUnwrap(result).get()
            let preview = try CSVDocument.parse(data: Data(contentsOf: url))
            XCTAssertEqual(url.lastPathComponent.contains("partial"), partial)
            XCTAssertEqual(preview.rows.count, partial ? 2 : 3)
            XCTAssertEqual(preview.rows[0].keyDurations, Array(repeating: 1.5, count: 7))
            XCTAssertEqual(preview.rows[1].keyDurations, [0.5] + Array(repeating: partial ? 1 : 2, count: 6))
            XCTAssertEqual(preview.totals, [2] + Array(repeating: partial ? 2.5 : 4.5, count: 6))
            if !partial { XCTAssertEqual(live, [2] + Array(repeating: 4.5, count: 6)) }
            session.stop(at: start.addingTimeInterval(7))
            XCTAssertEqual(completions, 1)
        }
    }

    func testKeyLimitsAndDuplicatePhysicalCodes() throws {
        for count in [0, 8] {
            XCTAssertThrowsError(try RecordingConfig(definitions: (0..<count).map {
                KeyDefinition(name: "Event", text: "", capturedCode: UInt16($0))
            }, duration: 1, interval: 1))
        }
        XCTAssertThrowsError(try RecordingConfig(definitions: [
            KeyDefinition(name: "A", text: " a "), KeyDefinition(name: "B", text: "A")
        ], duration: 1, interval: 1))
        XCTAssertThrowsError(try RecordingConfig(definitions: [
            KeyDefinition(name: "A", text: "a"), KeyDefinition(name: "B", text: "other", capturedCode: 0)
        ], duration: 1, interval: 1))
        XCTAssertThrowsError(try RecordingConfig(definitions: [
            KeyDefinition(name: "A", text: "unsupported")
        ], duration: 1, interval: 1))
    }

    func testSettingsMigratePersistRemoveAndReset() throws {
        let suite = "KeyRecorderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        defaults.set("Food", forKey: "key1Name")
        defaults.set("Key code 123", forKey: "key1Text")
        defaults.set(123, forKey: "key1Code")
        defaults.set("Lever", forKey: "key2Name")
        defaults.set("c", forKey: "key2Text")
        defaults.set("60", forKey: "duration")
        let catalog = SessionCatalog(rootURL: root)
        let state = AppState(defaults: defaults, sessionCatalog: catalog)
        XCTAssertEqual(state.keys.map(\.name), ["Food", "Lever"])
        XCTAssertEqual(state.keys.map(\.code), [123, 8])
        XCTAssertEqual(state.durationText, "60")
        for _ in 0..<8 { state.addKey() }
        XCTAssertEqual(state.keys.count, 7)
        XCTAssertEqual(Set(state.keys.compactMap(\.code)).count, 7)
        let restored = AppState(defaults: defaults, sessionCatalog: catalog)
        XCTAssertEqual(restored.keys, state.keys)
        restored.keys[0].text = "b"
        XCTAssertNil(restored.keys[0].capturedCode)
        let survivorIDs = Array(restored.keys.dropFirst().map(\.id))
        restored.removeKey(id: restored.keys[0].id)
        XCTAssertEqual(restored.keys.map(\.id), survivorIDs)
        restored.isRecording = true
        restored.addKey()
        restored.removeKey(id: restored.keys[0].id)
        XCTAssertEqual(restored.keys.count, 6)
        restored.isRecording = false
        for _ in 0..<8 { restored.removeKey(id: restored.keys[0].id) }
        XCTAssertEqual(restored.keys.count, 1)
        XCTAssertEqual(KeyDefinition.load(from: defaults).count, 1)
        restored.resetSettings()
        XCTAssertEqual(KeyDefinition.load(from: defaults), KeyDefinition.defaults)
    }

    func testCSVRejectsMissingColumnsAndInvalidNumbers() throws {
        for csv in ["interval,A,B\n0s - 1s,0.5\n", "interval,A\n0s - 1s,nan\n",
                    "interval,A\n0s - 1s,-1\n", "interval,\"unclosed\n"] {
            XCTAssertThrowsError(try CSVDocument.parse(data: Data(csv.utf8)))
        }
        let preview = try CSVDocument.parse(data: Data("interval,A\r\n0s - 1s,0.5\r\n".utf8))
        XCTAssertEqual(preview.totals, [0.5])
    }

}
