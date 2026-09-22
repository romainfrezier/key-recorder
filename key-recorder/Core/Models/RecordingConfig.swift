import Foundation
import CoreGraphics

struct KeyDefinition: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var text: String {
        didSet { if text != oldValue { capturedCode = nil } }
    }
    var capturedCode: CGKeyCode?

    var code: CGKeyCode? { capturedCode ?? KeyParser.keyCode(from: text) }

    static let defaults = [
        KeyDefinition(name: "Key 1", text: "a"),
        KeyDefinition(name: "Key 2", text: "b")
    ]

    static func load(from defaults: UserDefaults) -> [KeyDefinition] {
        if let data = defaults.data(forKey: "recordingKeys"),
           let keys = try? JSONDecoder().decode([KeyDefinition].self, from: data),
           (1...RecordingConfig.maximumKeys).contains(keys.count) {
            return keys
        }
        // Preserve names and physical key codes from the original two-key settings.
        return Self.defaults.enumerated().map { index, key in
            let prefix = "key\(index + 1)"
            return KeyDefinition(
                name: defaults.string(forKey: prefix + "Name") ?? key.name,
                text: defaults.string(forKey: prefix + "Text") ?? key.text,
                capturedCode: (defaults.object(forKey: prefix + "Code") as? NSNumber)
                    .flatMap { CGKeyCode(exactly: $0.intValue) }
            )
        }
    }
}

struct RecordingKey {
    let name: String
    let code: CGKeyCode
}

struct RecordingConfig {
    static let maximumKeys = 7

    let keys: [RecordingKey]
    let duration: TimeInterval
    let interval: TimeInterval

    init(definitions: [KeyDefinition], duration: TimeInterval, interval: TimeInterval) throws {
        guard (1...Self.maximumKeys).contains(definitions.count) else { throw AppError.invalidKey }
        var keys: [RecordingKey] = []
        for (index, definition) in definitions.enumerated() {
            guard let code = definition.code,
                  !keys.contains(where: { $0.code == code }) else { throw AppError.invalidKey }
            keys.append(RecordingKey(
                name: definition.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Key \(index + 1)" : definition.name,
                code: code
            ))
        }
        self.keys = keys
        self.duration = duration
        self.interval = interval
    }
}
