//
//  PermissionManager.swift
//  key-recorder
//
//  Manages Input Monitoring permission for macOS.
//

import Foundation
import CoreGraphics
import IOKit.hid

enum PermissionStatus {
    case granted
    case denied
    case unknown
}

struct PermissionState {
    let inputMonitoring: PermissionStatus
    
    var allGranted: Bool {
        // Key Recorder only listens to key events and never posts or modifies them.
        // Input Monitoring is therefore the only permission required to record.
        inputMonitoring == .granted
    }
    
    var message: String {
        if allGranted {
            return "Permissions look good ✅"
        }
        
        var missing: [String] = []
        if inputMonitoring != .granted {
            missing.append("Input Monitoring")
        }
        
        return "Grant \(missing.joined(separator: " and ")) permissions in System Settings > Privacy & Security."
    }
}

final class PermissionManager {
    static let shared = PermissionManager()
    
    private init() {}
    
    func checkPermissions(promptIfNeeded: Bool = false) -> PermissionState {
        let inputMonitoring = checkInputMonitoring(promptIfNeeded: promptIfNeeded)

        return PermissionState(inputMonitoring: inputMonitoring)
    }
    
    func ensureAllPermissions() throws {
        let state = checkPermissions(promptIfNeeded: false)
        
        guard state.inputMonitoring == .granted else {
            throw AppError.inputMonitoringPermissionMissing
        }
    }
    
    // MARK: - Private
    
    private func checkInputMonitoring(promptIfNeeded: Bool) -> PermissionStatus {
        if CGPreflightListenEventAccess() {
            return .granted
        }

        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        if promptIfNeeded, access != kIOHIDAccessTypeGranted {
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            if CGPreflightListenEventAccess() {
                return .granted
            }
        }

        switch access {
        case kIOHIDAccessTypeUnknown:
            return .unknown
        default:
            return .denied
        }
    }
}
