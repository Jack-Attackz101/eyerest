//
//  NudgeEngine.swift
//  Iris
//
//  Schedules periodic menu-bar posture nudges. Owns the nudge list, the
//  rotation index, and the next-nudge timer. The actual menu-bar mutation
//  happens in AppDelegate via the onShow / onHide callbacks.
//
//  These go through NudgeBudget like everything else. They are periodic rather
//  than event-driven, so a refusal cannot simply drop the nudge: that would end
//  the series. A refused nudge reschedules instead, and because the budget can
//  refuse late, when its coalescing window closes, the reschedule has to be
//  driven by the refusal callback rather than by the return of a call.
//

import Foundation
import AppKit

// MARK: - NudgeFrequency

enum NudgeFrequency: String, CaseIterable, Identifiable {
    case occasionally
    case regularly
    case often

    var id: String { rawValue }

    var label: String {
        switch self {
        case .occasionally: return "Occasionally"
        case .regularly:    return "Regularly"
        case .often:        return "Often"
        }
    }

    /// Random interval (seconds) for this tier.
    var randomInterval: TimeInterval {
        switch self {
        case .occasionally: return .random(in: (45 * 60)...(60 * 60))
        case .regularly:    return .random(in: (25 * 60)...(40 * 60))
        case .often:        return .random(in: (15 * 60)...(25 * 60))
        }
    }
}

// MARK: - NudgeEngine

final class NudgeEngine {

    private static let nudges: [String] = [
        "sit up straight",
        "roll your shoulders back",
        "unclench your jaw",
        "relax your shoulders",
        "take a deep breath",
        "drop your shoulders",
        "loosen your grip",
        "blink slowly, twice",
    ]

    // Wired by AppDelegate.
    var onShow: ((String) -> Void)?
    var onHide: (() -> Void)?

    private let engine = TimerEngine.shared
    private let defaults = UserDefaults.standard

    private var scheduleTimer: Timer?
    private var revertTimer: Timer?
    private var isNudgeVisible = false

    private enum Keys {
        static let nudgeIndex = "iris.nudgeIndex"
    }

    // MARK: - Lifecycle

    func start() {
        registerWakeObserver()
        scheduleNext()
    }

    // MARK: - Called by AppDelegate when state disallows a nudge or the popover opens.
    // Does NOT invoke onHide — AppDelegate owns the visual revert in those paths.
    func skipCurrentNudge() {
        guard isNudgeVisible else { return }
        isNudgeVisible = false
        revertTimer?.invalidate()
        revertTimer = nil
        scheduleNext()
    }

    // MARK: - Private scheduling

    private func scheduleNext() {
        scheduleTimer?.invalidate()
        let delay = engine.nudgeFrequency.randomInterval
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.nudgeTimerFired()
        }
    }

    private func nudgeTimerFired() {
        guard engine.postureNudgesEnabled else {
            scheduleNext()
            return
        }
        NudgeBudget.shared.request(.posture, text: nextNudgeText()) { [weak self] text in
            self?.showNudge(text)
        } onRefused: { [weak self] in
            // Not now. Try again shortly rather than losing the series.
            self?.retrySoon()
        }
    }

    /// The budget said no. Come back in half a minute, which is what this engine
    /// already did when the timer state was wrong.
    private func retrySoon() {
        guard !isNudgeVisible else { return }
        scheduleTimer?.invalidate()
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            self?.nudgeTimerFired()
        }
    }

    /// The budget granted it. The text comes from the budget, since it may be a
    /// combined line covering another source too.
    private func showNudge(_ text: String) {
        isNudgeVisible = true
        onShow?(String(text.prefix(44)))
        revertTimer?.invalidate()
        revertTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            guard let self, self.isNudgeVisible else { return }
            self.isNudgeVisible = false
            self.revertTimer = nil
            self.onHide?()
            self.scheduleNext()
        }
    }

    /// Kept for the rotation, which the budget does not own: the budget knows
    /// one line for posture nudges, this knows the eight this app rotates
    /// through. Used by AppDelegate when it asks the budget for a nudge.
    func nextNudgeText() -> String {
        let count = Self.nudges.count
        let raw   = defaults.integer(forKey: Keys.nudgeIndex)
        let index = ((raw % count) + count) % count
        defaults.set((index + 1) % count, forKey: Keys.nudgeIndex)
        return Self.nudges[index]
    }

    // MARK: - Sleep / wake

    private func registerWakeObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleDidWake() {
        scheduleTimer?.invalidate()
        guard !isNudgeVisible else { return }
        scheduleNext()
    }
}
