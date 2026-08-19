//
//  BlinkEngine.swift
//  Iris
//
//  Blink reminders. Timer based, no camera.
//
//  This deliberately does NOT go through NudgeBudget. The budget allows four
//  nudges an hour with eight minutes between them; a blink cue fires every
//  twenty seconds, so routing it through the gate would either starve it or
//  consume the entire budget and silence everything else. It gets its own quiet
//  path instead, and pays for that by being much lighter than a menu bar pill:
//  a small overlay that fades in and out near the cursor, or a sound, or
//  nothing.
//
//  Off by default. A cue firing every twenty seconds on first launch, unasked,
//  would be alarming, so onboarding raises it rather than the app just doing it.
//

import AppKit

// MARK: - Style

enum BlinkStyle: String, CaseIterable, Identifiable, Codable {
    case off
    case overlay
    case sound

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:     return "Off"
        case .overlay: return "Subtle overlay"
        case .sound:   return "Sound only"
        }
    }
}

// MARK: - Engine

final class BlinkEngine {

    /// The intervals offered. Anything shorter than 10 seconds is a twitch, and
    /// anything longer than a minute is not a blink reminder.
    static let allowedIntervals = [10, 20, 30, 60]

    private let engine = TimerEngine.shared
    private var timer: Timer?

    /// Set by AppDelegate. Shows the cue; the engine does not own any windows.
    var onCue: (() -> Void)?

    /// Anything that means the screen already belongs to something else. Set by
    /// AppDelegate, since the challenge, wind down and desk reset live in
    /// controllers rather than in TimerEngine.
    var isOverlayOnScreen: (() -> Bool)?

    // MARK: - Lifecycle

    func start() {
        reschedule()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call when the interval or the style changes, so the new one takes effect
    /// without waiting out the old one.
    func reschedule() {
        timer?.invalidate()
        timer = nil
        guard engine.blinkStyle != .off else { return }

        let interval = TimeInterval(engine.blinkIntervalSeconds)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Firing

    private func tick() {
        guard engine.blinkStyle != .off, !isSuppressed else { return }
        onCue?()
    }

    /// A blink cue is small, but it is still an interruption, so it stands down
    /// for everything that owns the screen or the moment.
    private var isSuppressed: Bool {
        if engine.timerState == .resting { return true }        // during a break
        if engine.timerState == .idle { return true }
        if engine.isSuspended { return true }                   // paused, quiet hours, a call, a schedule block
        if engine.isCallActive { return true }                  // a call even when Iris keeps running
        if isOverlayOnScreen?() == true { return true }         // challenge, wind down, desk reset
        if FlowDetector.shared.isFullscreenAppFrontmost { return true }
        return false
    }
}
