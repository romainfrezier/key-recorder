//
//  PermissionManager.swift
//  key-recorder
//
//  Manages Accessibility and Input Monitoring permissions for macOS.
//

import Foundation
import ApplicationServices
import CoreGraphics
import IOKit.hid

enum PermissionStatus {
    case granted
    case denied
    case unknown
}

struct PermissionState {
    let accessibility: PermissionStatus
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
        let accessibility = checkAccessibility(promptIfNeeded: promptIfNeeded)
        let inputMonitoring = checkInputMonitoring(promptIfNeeded: promptIfNeeded)
        
        return PermissionState(
            accessibility: accessibility,
            inputMonitoring: inputMonitoring
        )
    }
    
    func ensureAllPermissions() throws {
        let state = checkPermissions(promptIfNeeded: false)
        
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
            // This is the native macOS API that registers the app in
            // Privacy & Security > Input Monitoring.
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }

        // Check the exact capability used by KeyboardMonitor. The preflight
        // API can remain false for an already-listed app on newer macOS
        // versions, while a real passive event tap is usable.
        let events = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        )
        let testTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: events,
            callback: { _, _, event, _ in
                Unmanaged.passUnretained(event)
            },
            userInfo: nil
        )

        guard let testTap else { return .denied }
        CGEvent.tapEnable(tap: testTap, enable: false)
        CFMachPortInvalidate(testTap)
        return .granted
    }
}
