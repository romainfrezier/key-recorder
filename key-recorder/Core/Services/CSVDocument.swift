import Foundation

enum CSVDocumentError: LocalizedError {
    case invalidHeader
    case invalidRow(String)
    case invalidNumber(String)

    var errorDescription: String? {
        switch self {
        case .invalidHeader:
            return "The CSV header must contain an interval and one to seven measurement columns."
        case .invalidRow(let row):
            return "Invalid CSV row: \(row)"
        case .invalidNumber(let value):
            return "Invalid duration value: \(value)"
        }
    }
}

enum CSVDocument {
    static func parse(data: Data) throws -> CSVPreview {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CSVDocumentError.invalidHeader
        }

        let records = try parseRecords(text)
        guard let headers = records.first,
              (2...(RecordingConfig.maximumKeys + 1)).contains(headers.count),
              headers[0].lowercased() == "interval" else {
            throw CSVDocumentError.invalidHeader
        }

        var rows: [CSVPreview.Row] = []
        var totals: [Double]?
        for fields in records.dropFirst() {
            guard fields.count == headers.count else {
                throw CSVDocumentError.invalidRow(fields.joined(separator: ","))
            }
            let values = try fields.dropFirst().map(number)
            if fields[0].uppercased() == "TOTAL" {
                totals = values
            } else {
                rows.append(CSVPreview.Row(interval: fields[0], keyDurations: values))
            }
        }
        return CSVPreview(
            keyNames: Array(headers.dropFirst()),
            rows: rows,
            totals: totals ?? (0..<(headers.count - 1)).map { column in
                rows.reduce(0) { $0 + $1.keyDurations[column] }
            }
        )
    }

    private static func number(_ value: String) throws -> Double {
        guard let result = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              result.isFinite, result >= 0 else {
            throw CSVDocumentError.invalidNumber(value)
        }
        return result
    }

    private static func parseRecords(_ text: String) throws -> [[String]] {
        var records: [[String]] = []
        var fields: [String] = []
        var field = ""
        var quoted = false
        let characters = Array(text)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if quoted, index + 1 < characters.count, characters[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    quoted.toggle()
                }
            } else if character == "," && !quoted {
                fields.append(field)
                field = ""
            } else if character.isNewline && !quoted {
                if !fields.isEmpty || !field.trimmingCharacters(in: .whitespaces).isEmpty {
                    records.append(fields + [field])
                }
                fields = []
                field = ""
            } else {
                field.append(character)
            }
            index += 1
        }

        guard !quoted else { throw CSVDocumentError.invalidRow(field) }
        if !fields.isEmpty || !field.trimmingCharacters(in: .whitespaces).isEmpty {
            records.append(fields + [field])
        }
        return records
    }
}
