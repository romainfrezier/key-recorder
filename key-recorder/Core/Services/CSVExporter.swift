//
//  CSVExporter.swift
//  key-recorder
//
//  Handles CSV export with file system safety checks.
//

import Foundation

enum CSVExportError: Error {
    case directoryCreationFailed
    case invalidFileName
    case writeError(String)
}

enum CSVExporter {
    static func export(records: [IntervalRecord], config: RecordingConfig, to url: URL) throws {
        // Validate URL
        let validatedURL = try validateAndPrepareURL(url)
        
        // Build CSV content
        let csv = buildCSV(records: records, config: config)
        
        // Write with proper error handling
        do {
            guard FileManager.default.isWritableFile(atPath: validatedURL.deletingLastPathComponent().path) else {
                throw CSVExportError.writeError("Directory is not writable")
            }
            
            try csv.write(to: validatedURL, atomically: true, encoding: .utf8)
        } catch let error as CSVExportError {
            throw error
        } catch {
            // Check for common errors
            let nsError = error as NSError
            if nsError.domain == NSPOSIXErrorDomain {
                switch nsError.code {
                case 28: // ENOSPC
                    throw CSVExportError.writeError("Disk full")
                case 13: // EACCES
                    throw CSVExportError.writeError("Permission denied")
                default:
                    throw CSVExportError.writeError("Write failed: \(error.localizedDescription)")
                }
            } else {
                throw CSVExportError.writeError("Write failed: \(error.localizedDescription)")
            }
        }
    }
    
    private static func validateAndPrepareURL(_ url: URL) throws -> URL {
        // Ensure URL has .csv extension
        var validatedURL = url
        let pathExtension = url.pathExtension.lowercased()
        if pathExtension != "csv" {
            validatedURL = url.appendingPathExtension("csv")
        }
        
        // Validate filename
        let fileName = validatedURL.lastPathComponent
        guard !fileName.isEmpty else {
            throw CSVExportError.invalidFileName
        }
        
        // Create directory if needed
        let directory = validatedURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                throw CSVExportError.directoryCreationFailed
            }
        }
        
        return validatedURL
    }
    
    private static func buildCSV(records: [IntervalRecord], config: RecordingConfig) -> String {
        let key1Header = sanitizeHeader(config.key1Name)
        let key2Header = sanitizeHeader(config.key2Name)
        
        var csv = "interval,\(key1Header),\(key2Header)\n"
        
        guard let firstRecord = records.first else {
            // If no records, still create file with headers and empty totals
            csv += "\n"
            csv += "TOTAL,0.000,0.000\n"
            return csv
        }
        
        for record in records {
            let startSeconds = Int(record.intervalStart.timeIntervalSince(firstRecord.intervalStart).rounded(.down))
            let endSeconds = Int(record.intervalEnd.timeIntervalSince(firstRecord.intervalStart).rounded(.down))
            let intervalLabel = "\(startSeconds)s - \(endSeconds)s"
            
            csv += [
                intervalLabel,
                String(format: "%.3f", record.key1Duration),
                String(format: "%.3f", record.key2Duration)
            ].joined(separator: ",") + "\n"
        }
        
        let totalKey1 = records.reduce(0) { $0 + $1.key1Duration }
        let totalKey2 = records.reduce(0) { $0 + $1.key2Duration }
        
        csv += "\n"
        csv += "TOTAL,"
        csv += String(format: "%.3f", totalKey1)
        csv += ","
        csv += String(format: "%.3f", totalKey2)
        csv += "\n"
        
        return csv
    }
    
    private static func sanitizeHeader(_ header: String) -> String {
        return header
            .replacingOccurrences(of: ",", with: "_")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}