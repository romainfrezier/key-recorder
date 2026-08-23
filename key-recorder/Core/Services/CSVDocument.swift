import Foundation

enum CSVDocumentError: LocalizedError {
    case invalidHeader
    case invalidRow(String)
    case invalidNumber(String)

    var errorDescription: String? {
        switch self {
        case .invalidHeader:
            return "The CSV header must contain an interval and two measurement columns."
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

        let lines = text.components(separatedBy: .newlines)
        guard let headerLine = lines.first, !headerLine.isEmpty else {
            throw CSVDocumentError.invalidHeader
        }

        let headers = parseLine(headerLine)
        guard headers.count >= 3, headers[0].lowercased() == "interval" else {
            throw CSVDocumentError.invalidHeader
        }

        var rows: [CSVPreview.Row] = []
        var totalKey1 = 0.0
        var totalKey2 = 0.0

        for line in lines.dropFirst() where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let fields = parseLine(line)
            guard fields.count >= 3 else { throw CSVDocumentError.invalidRow(line) }
            if fields[0].uppercased() == "TOTAL" {
                totalKey1 = try number(fields[1])
                totalKey2 = try number(fields[2])
                continue
            }

            rows.append(
                CSVPreview.Row(
                    interval: fields[0],
                    key1Duration: try number(fields[1]),
                    key2Duration: try number(fields[2])
                )
            )
        }

        if rows.isEmpty {
            totalKey1 = 0
            totalKey2 = 0
        }

        return CSVPreview(
            key1Name: headers[1],
            key2Name: headers[2],
            rows: rows,
            totalKey1: totalKey1,
            totalKey2: totalKey2
        )
    }

    private static func number(_ value: String) throws -> Double {
        guard let result = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw CSVDocumentError.invalidNumber(value)
        }
        return result
    }

    private static func parseLine(_ line: String) -> [String] {
        var fields: [String] = []
        var field = ""
        var quoted = false
        let characters = Array(line)
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
            } else {
                field.append(character)
            }
            index += 1
        }

        fields.append(field)
        return fields
    }
}
