//
//  StandUpEngine.swift
//  Iris
//
//  Nudges the user to stand for 2 minutes every hour of active work.
//

import Foundation

final class StandUpEngine {

    private let engine = TimerEngine.shared
    private var workedSeconds: Int = 0
    private var timer: Timer?

    /// Called by AppDelegate to show the stand-up nudge in the menu bar.
    var onNudge: (() -> Void)?

    private let thresholdSeconds = 60 * 60   // 1 hour

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

    private func tick() {
        guard engine.standUpModeEnabled else { return }
        guard engine.timerState == .counting, !engine.isSuspended else { return }

        workedSeconds += 1
        if workedSeconds >= thresholdSeconds {
            workedSeconds = 0
            onNudge?()
        }
    }
}
