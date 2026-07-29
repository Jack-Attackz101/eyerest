//
//  WristReliefEngine.swift
//  Iris
//
//  Detects long keyboard and mouse sessions and prompts a shake-out.
//  When Accessibility is granted: uses a global event monitor for accuracy.
//  When Accessibility is denied: falls back to tracking continuous work time.
//

import Foundation
import AppKit

final class WristReliefEngine {

    private let engine = TimerEngine.shared

    /// Called by AppDelegate to show the wrist relief nudge.
    var onNudge: (() -> Void)?

    // Global event monitor (requires Accessibility).
    private var eventMonitor: Any?
    // Fallback: work-time counter when Accessibility is not granted.
    private var fallbackTimer: Timer?
    private var fallbackWorkedSeconds: Int = 0

    // Threshold: prompt after this many continuous seconds of activity.
    private let thresholdSeconds = 45 * 60   // 45 minutes
    // Activity tracking for global monitor path.
    private var activeSeconds: Int = 0
    private var activityTimer: Timer?
    private var lastActivityDate: Date?

    func start() {
        if AXIsProcessTrusted() {
            startGlobalMonitor()
        } else {
            startFallback()
        }
    }

    func stop() {
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
        activityTimer?.invalidate(); activityTimer = nil
        fallbackTimer?.invalidate(); fallbackTimer = nil
    }

    // MARK: - Global monitor path

    private func startGlobalMonitor() {
        let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.lastActivityDate = Date()
        }

        // Tick every second to accumulate contiguous active time.
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.activityTick()
        }
        RunLoop.main.add(t, forMode: .common)
        activityTimer = t
    }

    private func activityTick() {
        guard engine.wristReliefEnabled else { activeSeconds = 0; return }
        // Consider the user active if an event arrived within the last 5 seconds.
        let isActive = lastActivityDate.map { Date().timeIntervalSince($0) < 5 } ?? false
        if isActive {
            activeSeconds += 1
            if activeSeconds >= thresholdSeconds {
                activeSeconds = 0
                onNudge?()
            }
        } else {
            activeSeconds = 0
        }
    }

    // MARK: - Fallback path (no Accessibility)

    private func startFallback() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.fallbackTick()
        }
        RunLoop.main.add(t, forMode: .common)
        fallbackTimer = t
    }

    private func fallbackTick() {
        guard engine.wristReliefEnabled else { fallbackWorkedSeconds = 0; return }
        guard engine.timerState == .counting, !engine.isSuspended else {
            fallbackWorkedSeconds = 0; return
        }
        fallbackWorkedSeconds += 1
        if fallbackWorkedSeconds >= thresholdSeconds {
            fallbackWorkedSeconds = 0
            onNudge?()
        }
    }
}
