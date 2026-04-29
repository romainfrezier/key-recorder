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

final class RecordingSession {
    var onTick: ((TimeInterval) -> Void)?
    var onFinished: ((Result<Void, Error>) -> Void)?
    var onLiveUpdate: ((TimeInterval, TimeInterval) -> Void)?

    private let config: RecordingConfig
    private let outputURL: URL

    private var startDate: Date?
    private var endDate: Date?
    private var timer: Timer?

    // Current physical state.
    private var key1IsDown = false
    private var key2IsDown = false

    // Start date of the current press for each key.
    private var key1PressStart: Date?
    private var key2PressStart: Date?

    // Accumulated pressed duration per interval.
    private var key1Durations: [TimeInterval] = []
    private var key2Durations: [TimeInterval] = []
    private var intervalCount: Int = 0

    init(config: RecordingConfig, outputURL: URL) {
        self.config = config
        self.outputURL = outputURL
    }

    func start() {
        let now = Date()
        startDate = now
        endDate = now.addingTimeInterval(config.duration)
        intervalCount = Int(ceil(config.duration / config.interval))
        key1Durations = Array(repeating: 0, count: intervalCount)
        key2Durations = Array(repeating: 0, count: intervalCount)
        key1PressStart = nil
        key2PressStart = nil
        key1IsDown = false
        key2IsDown = false

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func handleEvent(keyCode: CGKeyCode, isDown: Bool) {
        guard let startDate, let endDate else { return }

        let now = Date()

        // Ignore events completely outside the recording window.
        if now < startDate || now > endDate {
            return
        }

        if keyCode == config.key1Code {
            if isDown {
                if !key1IsDown {
                    key1IsDown = true
                    key1PressStart = now
                }
            } else {
                if key1IsDown, let pressStart = key1PressStart {
                    key1IsDown = false
                    key1PressStart = nil
                    accumulateDuration(
                        from: pressStart,
                        to: now,
                        into: &key1Durations
                    )
                }
            }
        }

        if keyCode == config.key2Code {
            if isDown {
                if !key2IsDown {
                    key2IsDown = true
                    key2PressStart = now
                }
            } else {
                if key2IsDown, let pressStart = key2PressStart {
                    key2IsDown = false
                    key2PressStart = nil
                    accumulateDuration(
                        from: pressStart,
                        to: now,
                        into: &key2Durations
                    )
                }
            }
        }
    }

    private func tick() {
        guard let endDate else { return }

        let now = Date()
        let remaining = max(0, endDate.timeIntervalSince(now))
        onTick?(remaining)

        let totals = currentLiveTotals(at: now)
        onLiveUpdate?(totals.0, totals.1)

        if now >= endDate {
            finish()
        }
    }

    private func accumulateDuration(
        from pressStart: Date,
        to pressEnd: Date,
        into durations: inout [TimeInterval]
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
                durations[index] += overlapEnd.timeIntervalSince(overlapStart)
            }
        }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil

        guard let endDate else {
            onFinished?(.failure(AppError.recordingFailed("Session state invalid")))
            return
        }

        // Close any key still being held when the recording ends.
        if key1IsDown, let pressStart = key1PressStart {
            accumulateDuration(from: pressStart, to: endDate, into: &key1Durations)
            key1IsDown = false
            key1PressStart = nil
        }

        if key2IsDown, let pressStart = key2PressStart {
            accumulateDuration(from: pressStart, to: endDate, into: &key2Durations)
            key2IsDown = false
            key2PressStart = nil
        }

        do {
            let records = buildRecords()
            try CSVExporter.export(records: records, config: config, to: outputURL)
            onFinished?(.success(()))
        } catch {
            onFinished?(.failure(error))
        }
    }

    private func buildRecords() -> [IntervalRecord] {
        guard let startDate else { return [] }

        var records: [IntervalRecord] = []
        records.reserveCapacity(intervalCount)

        for index in 0..<intervalCount {
            let intervalStart = startDate.addingTimeInterval(Double(index) * config.interval)
            let nominalEnd = intervalStart.addingTimeInterval(config.interval)
            let realEnd = min(nominalEnd, startDate.addingTimeInterval(config.duration))

            records.append(
                IntervalRecord(
                    intervalStart: intervalStart,
                    intervalEnd: realEnd,
                    key1Duration: key1Durations[index],
                    key2Duration: key2Durations[index]
                )
            )
        }

        return records
    }
    
    private func currentLiveTotals(at now: Date) -> (TimeInterval, TimeInterval) {
        let storedKey1 = key1Durations.reduce(0, +)
        let storedKey2 = key2Durations.reduce(0, +)

        let liveKey1: TimeInterval
        if key1IsDown, let pressStart = key1PressStart {
            liveKey1 = max(0, now.timeIntervalSince(pressStart))
        } else {
            liveKey1 = 0
        }

        let liveKey2: TimeInterval
        if key2IsDown, let pressStart = key2PressStart {
            liveKey2 = max(0, now.timeIntervalSince(pressStart))
        } else {
            liveKey2 = 0
        }

        return (storedKey1 + liveKey1, storedKey2 + liveKey2)
    }
}
