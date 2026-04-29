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
    private var eventQueue: DispatchQueue?
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
        
        // Use a dedicated queue for events instead of main thread
        let eventQueue = DispatchQueue(label: "com.key-recorder.event-tap", qos: .userInteractive)
        self.eventQueue = eventQueue
        
        // Queue for callbacks back to the application
        let callbackQueue = DispatchQueue(label: "com.key-recorder.callbacks", qos: .userInitiated)
        self.callbackQueue = callbackQueue
        
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else {
                return Unmanaged.passRetained(event)
            }

            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
            
            // Handle event on the event queue
            monitor.handleEventAsync(type, event: event)

            return Unmanaged.passRetained(event)
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly, // Safer option
            eventsOfInterest: CGEventMask(events),
            callback: callback,
            userInfo: refcon
        ) else {
            throw MonitorError.failedToCreateEventTap
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        // Add to event queue's run loop instead of main
        eventQueue.async { [weak self] in
            guard let self = self else { return }
            let runLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }

        self.eventTap = tap
        self.runLoopSource = source
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

        if let source = runLoopSource {
            // Remove from the event queue's run loop
            eventQueue?.async { [weak self] in
                guard let self = self else { return }
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        
        // Stop the run loop
        eventQueue?.async { [weak self] in
            CFRunLoopStop(CFRunLoopGetCurrent())
        }

        eventTap = nil
        runLoopSource = nil
        eventQueue = nil
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