//
//  ScrollFatigueEngine.swift
//  Iris
//
//  After heavy scrolling, shows a wrist-reset cue.
//  Requires Accessibility permission for global scroll monitoring.
//  Degrades gracefully if permission is not granted (nudge is simply skipped).
//

import Foundation
import AppKit

final class ScrollFatigueEngine {

    private let engine = TimerEngine.shared

    /// Called by AppDelegate to show the scroll fatigue nudge.
    var onNudge: (() -> Void)?

    private var eventMonitor: Any?
    // Accumulated scroll magnitude in the current measurement window.
    private var scrollMagnitude: Double = 0
    // Window length in seconds before resetting scroll accumulation.
    private let windowSeconds: TimeInterval = 5 * 60   // 5 minutes
    private var windowTimer: Timer?
    // Threshold: total scroll magnitude that triggers a nudge.
    private let magnitudeThreshold: Double = 8000

    func start() {
        guard AXIsProcessTrusted() else { return }
        startMonitor()
    }

    func stop() {
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
        windowTimer?.invalidate(); windowTimer = nil
    }

    private func startMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.engine.scrollFatigueEnabled else { return }
            let delta = abs(event.scrollingDeltaY) + abs(event.scrollingDeltaX)
            self.scrollMagnitude += Double(delta)
            if self.scrollMagnitude >= self.magnitudeThreshold {
                self.scrollMagnitude = 0
                self.onNudge?()
            }
        }

        // Reset the accumulator every window period.
        let t = Timer(timeInterval: windowSeconds, repeats: true) { [weak self] _ in
            self?.scrollMagnitude = 0
        }
        RunLoop.main.add(t, forMode: .common)
        windowTimer = t
    }
}
