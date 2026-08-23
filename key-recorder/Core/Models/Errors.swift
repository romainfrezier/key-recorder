//
//  Errors.swift
//  key-recorder
//
//  Created by Romain on 24.03.2026.
//

import Foundation

enum AppError: LocalizedError {
    case invalidKey
    case invalidDuration
    case invalidInterval
    case intervalGreaterThanDuration
    case inputMonitoringPermissionMissing
    case recordingFailed(String)

    var localizationKey: String {
        switch self {
        case .invalidKey: return "Please enter two simple supported keys (example: a, b, 1)."
        case .invalidDuration: return "Duration must be a positive number."
        case .invalidInterval: return "Interval must be a positive number."
        case .intervalGreaterThanDuration: return "Interval cannot be greater than duration."
        case .inputMonitoringPermissionMissing: return "Input Monitoring permission is missing. Open System Settings > Privacy & Security > Input Monitoring."
        case .recordingFailed: return "Recording failed"
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Please enter two simple supported keys (example: a, b, 1)."
        case .invalidDuration:
            return "Duration must be a positive number."
        case .invalidInterval:
            return "Interval must be a positive number."
        case .intervalGreaterThanDuration:
            return "Interval cannot be greater than duration."
        case .inputMonitoringPermissionMissing:
            return "Input Monitoring permission is missing. Open System Settings > Privacy & Security > Input Monitoring."
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        }
    }
}

enum MonitorError: LocalizedError {
    case failedToCreateEventTap

    var localizationKey: String {
        "Unable to create CGEvent tap. Check Input Monitoring permission."
    }

    var errorDescription: String? {
        switch self {
        case .failedToCreateEventTap:
            return "Unable to create CGEvent tap. Check Input Monitoring permission."
        }
    }
}
