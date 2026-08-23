//
//  PermissionManager.swift
//  key-recorder
//
//  Manages Accessibility and Input Monitoring permissions for macOS.
//

import Foundation
import ApplicationServices
import CoreGraphics

enum PermissionStatus {
    case granted
    case denied
    case unknown
}

struct PermissionState {
    let accessibility: PermissionStatus
    let inputMonitoring: PermissionStatus
    
    var allGranted: Bool {
        accessibility == .granted && inputMonitoring == .granted
    }
    
    var message: String {
        if allGranted {
            return "Permissions look good ✅"
        }
        
        var missing: [String] = []
        if accessibility != .granted {
            missing.append("Accessibility")
        }
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
        let accessibility = checkAccessibility(promptIfNeeded: promptIfNeeded)
        let inputMonitoring = checkInputMonitoring(promptIfNeeded: promptIfNeeded)
        
        return PermissionState(
            accessibility: accessibility,
            inputMonitoring: inputMonitoring
        )
    }
    
    func ensureAllPermissions() throws {
        let state = checkPermissions(promptIfNeeded: false)
        
        guard state.accessibility == .granted else {
            throw AppError.accessibilityPermissionMissing
        }
        
        guard state.inputMonitoring == .granted else {
            throw AppError.inputMonitoringPermissionMissing
        }
    }
    
    // MARK: - Private
    
    private func checkAccessibility(promptIfNeeded: Bool) -> PermissionStatus {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfNeeded] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        return isTrusted ? .granted : .denied
    }
    
    private func checkInputMonitoring(promptIfNeeded: Bool) -> PermissionStatus {
        if promptIfNeeded {
            _ = CGRequestListenEventAccess()
        }

        return CGPreflightListenEventAccess() ? .granted : .denied
    }
}
