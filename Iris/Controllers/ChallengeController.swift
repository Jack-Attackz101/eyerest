//
//  ChallengeController.swift
//  Iris
//
//  Presents the physical-challenge overlay on all displays after the screen
//  wakes from lock, gated to the user's wake window and once per day.
//  The overlay cannot be force-dismissed — the Done button appears only after
//  the exercise's hold duration elapses.
//

import AppKit
import SwiftUI

private final class ChallengePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class ChallengeController {

    private let engine: TimerEngine
    private var model: ChallengeModel?
    private var panels: [NSPanel] = []
    private var countdownTimer: Timer?
    private var keyboardMonitor: Any?
    private var isShowing = false
    var isPresenting: Bool { isShowing }

    private let defaults = UserDefaults.standard
    private let lastChallengeKey = "iris.lastChallengeDate"

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(engine: TimerEngine) {
        self.engine = engine
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(screensDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    // MARK: - Wake handling

    @objc private func screensDidWake() {
        guard shouldPresentNow() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.present()
        }
    }

    // MARK: - Gate logic

    private func shouldPresentNow() -> Bool {
        let challenge = engine.challenge
        guard challenge.isEnabled, !isShowing else { return false }

        let now = Date()
        let today = Self.dayFormatter.string(from: now)
        guard defaults.string(forKey: lastChallengeKey) != today else { return false }
        guard isWithinWakeWindow(now: now, challenge: challenge) else { return false }

        defaults.set(today, forKey: lastChallengeKey)
        return true
    }

    private func isWithinWakeWindow(now: Date, challenge: Challenge) -> Bool {
        let cal = Calendar.current
        let nowMin  = cal.component(.hour, from: now)       * 60 + cal.component(.minute, from: now)
        let wakeMin = cal.component(.hour, from: challenge.wakeTime)  * 60 + cal.component(.minute, from: challenge.wakeTime)
        let bedMin  = cal.component(.hour, from: challenge.bedtime)   * 60 + cal.component(.minute, from: challenge.bedtime)

        if wakeMin <= bedMin {
            return nowMin >= wakeMin && nowMin < bedMin
        } else {
            // Window crosses midnight (e.g. wake 22:00, bed 06:00).
            return nowMin >= wakeMin || nowMin < bedMin
        }
    }

    // MARK: - Present / dismiss

    func presentIfDue() {
        guard shouldPresentNow() else { return }
        present()
    }

#if DEBUG
    /// Bypass the date gate — for demo and testing only.
    func presentNow() {
        present()
    }
#endif

    private func present() {
        guard !isShowing else { return }
        isShowing = true

        let exercise = engine.challenge.resolvedExercise()
        let m = ChallengeModel()
        m.secondsRemaining = exercise.holdDuration
        m.streak = StatsEngine.shared.challengeStreak
        m.onDone = { [weak self] in
            StatsEngine.shared.recordChallengeComplete()
            self?.dismiss()
        }
        m.onSkip = { [weak self] in
            StatsEngine.shared.recordChallengeSkipped()
            self?.dismiss()
        }
        model = m

        buildPanels(model: m, exercise: exercise)
        for panel in panels { panel.orderFrontRegardless() }
        panels.first?.makeKeyAndOrderFront(nil)
        startKeyboardSwallow()

        DispatchQueue.main.async { m.visible = true }
        startCountdown(model: m, exercise: exercise)
    }

    private func dismiss() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        stopKeyboardSwallow()
        model?.visible = false
        let closing = panels
        panels = []
        isShowing = false
        model = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            closing.forEach { $0.orderOut(nil) }
        }
    }

    // MARK: - Countdown

    private func startCountdown(model: ChallengeModel, exercise: Exercise) {
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak model] t in
            guard let model else { t.invalidate(); return }
            if model.secondsRemaining > 0 {
                model.secondsRemaining -= 1
            } else {
                t.invalidate()
                withAnimation(.easeInOut(duration: 0.4)) { model.doneEnabled = true }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    // MARK: - Input swallowing (keyboard only; mouse reaches SwiftUI buttons)

    private func startKeyboardSwallow() {
        guard keyboardMonitor == nil else { return }
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { _ in nil }
    }

    private func stopKeyboardSwallow() {
        if let m = keyboardMonitor { NSEvent.removeMonitor(m); keyboardMonitor = nil }
    }

    // MARK: - Panels

    private func buildPanels(model: ChallengeModel, exercise: Exercise) {
        panels.forEach { $0.orderOut(nil) }
        panels = NSScreen.screens.map { makePanel(for: $0, model: model, exercise: exercise) }
    }

    private func makePanel(for screen: NSScreen, model: ChallengeModel, exercise: Exercise) -> NSPanel {
        let panel = ChallengePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.hasShadow = false
        panel.hidesOnDeactivate = false

        let host = NSHostingView(rootView: ChallengeView(model: model, exercise: exercise))
        host.frame = NSRect(origin: .zero, size: screen.frame.size)
        panel.contentView = host
        panel.setFrame(screen.frame, display: true)
        return panel
    }
}
