//
//  KeyboardMonitor.swift
//  key-recorder
//
//  Manages global keyboard event monitoring with thread safety.
//

import Foundation
import CoreGraphics

final class KeyboardMonitor {
    var onEvent: ((CGKeyCode, Bool) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var callbackQueue: DispatchQueue?
    
    private let lock = NSLock()
    private var isRunning = false

    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isRunning else { return }
        
        // Verify Input Monitoring permission first
        let permissionState = PermissionManager.shared.checkPermissions(promptIfNeeded: false)
        guard permissionState.inputMonitoring == .granted else {
            throw AppError.inputMonitoringPermissionMissing
        }

        let events = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        // Queue for callbacks back to the application
        let callbackQueue = DispatchQueue(label: "com.key-recorder.callbacks", qos: .userInitiated)
        self.callbackQueue = callbackQueue
        
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
            
            // Keep the event-tap callback short and forward application work.
            monitor.handleEventAsync(type, event: event)

            return Unmanaged.passUnretained(event)
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly, // Safer option
            eventsOfInterest: CGEventMask(events),
            callback: callback,
            userInfo: refcon
        ) else {
            throw MonitorError.failedToCreateEventTap
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let runLoop = CFRunLoopGetMain()
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        self.runLoop = runLoop
        self.isRunning = true
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        guard isRunning else { return }
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }

        if let source = runLoopSource, let runLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        runLoop = nil
        callbackQueue = nil
        isRunning = false
    }
    
    private func handleEventAsync(_ type: CGEventType, event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let isDown: Bool
        
        switch type {
        case .keyDown:
            isDown = true
        case .keyUp:
            isDown = false
        default:
            return
        }
        
        // Callback on the callback queue for thread safety
        callbackQueue?.async { [weak self] in
            self?.onEvent?(keyCode, isDown)
        }
    }
}
