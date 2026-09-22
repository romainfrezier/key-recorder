//
//  RecordingSession.swift
//  key-recorder
//
//  Created by Romain on 24.03.2026.
//

import Foundation
import CoreGraphics

// Import models from the same module (Core/Models)
// They're part of the same target, so no explicit import needed

@MainActor
final class RecordingSession {
    var onTick: ((TimeInterval) -> Void)?
    var onFinished: ((Result<URL, Error>) -> Void)?
    var onLiveUpdate: (([TimeInterval]) -> Void)?

    private let config: RecordingConfig
    private let outputURL: URL

    private var startDate: Date?
    private var endDate: Date?
    private var timer: Timer?

    private var pressStarts: [Date?] = []
    private var durations: [[TimeInterval]] = []
    private var intervalCount: Int = 0
    private var didFinish = false

    init(config: RecordingConfig, outputURL: URL) {
        self.config = config
        self.outputURL = outputURL
    }

    func start(at now: Date = Date()) {
        startDate = now
        endDate = now.addingTimeInterval(config.duration)
        intervalCount = Int(ceil(config.duration / config.interval))
        durations = Array(repeating: Array(repeating: 0, count: intervalCount), count: config.keys.count)
        pressStarts = Array(repeating: nil, count: config.keys.count)
        didFinish = false

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func handleEvent(keyCode: CGKeyCode, isDown: Bool, at now: Date = Date()) {
        guard !didFinish, let startDate, let endDate,
              now >= startDate, now <= endDate,
              let index = config.keys.firstIndex(where: { $0.code == keyCode }) else { return }

        if isDown {
            // Repeated key-down events must not restart a held key's timer.
            if pressStarts[index] == nil { pressStarts[index] = now }
        } else if let pressStart = pressStarts[index] {
            pressStarts[index] = nil
            accumulateDuration(from: pressStart, to: now, keyIndex: index)
        }
    }

    func tick(at now: Date = Date()) {
        guard !didFinish, let endDate else { return }

        let remaining = max(0, endDate.timeIntervalSince(now))
        onTick?(remaining)

        let totals = currentLiveTotals(at: now)
        onLiveUpdate?(totals)

        if now >= endDate {
            finish(at: endDate, partial: false)
        }
    }

    func stop(at now: Date = Date()) {
        guard !didFinish else { return }
        finish(at: min(now, endDate ?? now), partial: true)
    }

    private func accumulateDuration(
        from pressStart: Date,
        to pressEnd: Date,
        keyIndex: Int
    ) {
        guard let recordingStart = startDate else { return }

        let recordingEnd = recordingStart.addingTimeInterval(config.duration)

        let clampedStart = max(pressStart, recordingStart)
        let clampedEnd = min(pressEnd, recordingEnd)

        guard clampedEnd > clampedStart else { return }

        for index in 0..<intervalCount {
            let intervalStart = recordingStart.addingTimeInterval(Double(index) * config.interval)
            let nominalEnd = intervalStart.addingTimeInterval(config.interval)
            let intervalEnd = min(nominalEnd, recordingEnd)

            let overlapStart = max(clampedStart, intervalStart)
            let overlapEnd = min(clampedEnd, intervalEnd)

            if overlapEnd > overlapStart {
                durations[keyIndex][index] += overlapEnd.timeIntervalSince(overlapStart)
            }
        }
    }

    private func finish(at finishDate: Date, partial: Bool) {
        guard !didFinish else { return }
        didFinish = true
        timer?.invalidate()
        timer = nil

        guard let endDate else {
            onFinished?(.failure(AppError.recordingFailed("Session state invalid")))
            return
        }

        let effectiveEndDate = min(finishDate, endDate)

        // Close every held key independently, including a partial recording.
        for index in config.keys.indices {
            if let pressStart = pressStarts[index] {
                accumulateDuration(from: pressStart, to: effectiveEndDate, keyIndex: index)
                pressStarts[index] = nil
            }
        }

        do {
            let records = buildRecords(until: effectiveEndDate)
            let destination = partial ? partialURL : outputURL
            try CSVExporter.export(records: records, config: config, to: destination)
            onFinished?(.success(destination))
        } catch {
            onFinished?(.failure(error))
        }
    }

    private var partialURL: URL {
        let baseName = outputURL.deletingPathExtension().lastPathComponent + "-partial"
        return outputURL.deletingLastPathComponent()
            .appendingPathComponent(baseName)
            .appendingPathExtension(outputURL.pathExtension.isEmpty ? "csv" : outputURL.pathExtension)
    }

    private func buildRecords(until recordingEnd: Date) -> [IntervalRecord] {
        guard let startDate else { return [] }

        var records: [IntervalRecord] = []
        records.reserveCapacity(intervalCount)

        for index in 0..<intervalCount {
            let intervalStart = startDate.addingTimeInterval(Double(index) * config.interval)
            guard intervalStart < recordingEnd else { break }
            let nominalEnd = intervalStart.addingTimeInterval(config.interval)
            let realEnd = min(nominalEnd, recordingEnd)

            records.append(
                IntervalRecord(
                    intervalStart: intervalStart,
                    intervalEnd: realEnd,
                    keyDurations: durations.map { $0[index] }
                )
            )
        }

        return records
    }
    
    private func currentLiveTotals(at now: Date) -> [TimeInterval] {
        let effectiveNow = min(now, endDate ?? now)
        return config.keys.indices.map { index in
            let held = pressStarts[index].map { max(0, effectiveNow.timeIntervalSince($0)) } ?? 0
            return durations[index].reduce(0, +) + held
        }
    }
}
