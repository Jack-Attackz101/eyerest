//
//  WaterReminderEngine.swift
//  Iris
//
//  Tracks active work time and fires a water nudge after the threshold.
//  The host (AppDelegate) shows/hides the nudge; this engine owns the counter.
//

import Foundation

final class WaterReminderEngine {

    private let engine = TimerEngine.shared
    private var workedSeconds: Int = 0
    private var timer: Timer?

    /// Threshold: nudge after this many seconds of active work.
    private let thresholdSeconds = 45 * 60   // 45 minutes

    /// Called when the threshold fires. AppDelegate wires this to show a menu-bar nudge.
    var onNudge: (() -> Void)?

    func start() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Reset counter (called when user taps "Drank it").
    func resetCounter() {
        workedSeconds = 0
    }

    private func tick() {
        guard engine.waterRemindersEnabled else { return }
        guard engine.timerState == .counting, !engine.isSuspended else { return }
        guard !engine.waterNudgePending else { return }

        workedSeconds += 1
        if workedSeconds >= thresholdSeconds {
            workedSeconds = 0
            engine.waterNudgePending = true
            onNudge?()
        }
    }
}
