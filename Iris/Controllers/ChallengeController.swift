//
//  ChallengeController.swift
//  Iris
//
//  Presents the physical-challenge overlay on all displays after the screen
//  wakes from lock (Feature 7), honoring the trigger mode and once-per-day gate.
//

import AppKit
import SwiftUI

/// A borderless panel that can become key so the "Done" button is clickable.
private final class ChallengePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class ChallengeController {

    private let engine: TimerEngine
    private let model = ChallengeModel()
    private var panels: [NSPanel] = []
    private var countdownTimer: Timer?
    private var isShowing = false

    private let defaults = UserDefaults.standard
    private let lastShownKey = "iris.lastChallengeDateShown"

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(engine: TimerEngine) {
        self.engine = engine
        model.onDone = { [weak self] in self?.dismiss() }
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
        // Let the login screen fully dismiss first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.present()
        }
    }

    private func shouldPresentNow() -> Bool {
        let challenge = engine.challenge
        guard challenge.isEnabled, !isShowing else { return false }

        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let today = Self.dayFormatter.string(from: now)

        switch challenge.triggerMode {
        case .everyUnlock:
            return true

        case .morningOnly:
            guard hour >= challenge.morningStartHour else { return false }
            guard defaults.string(forKey: lastShownKey) != today else { return false }
            defaults.set(today, forKey: lastShownKey)
            return true

        case .both:
            // Fires every unlock; also record the morning occurrence for the day.
            if hour >= challenge.morningStartHour, defaults.string(forKey: lastShownKey) != today {
                defaults.set(today, forKey: lastShownKey)
            }
            return true
        }
    }

    // MARK: - Present / dismiss

    /// Exposed so the app can trigger a challenge on first launch if appropriate.
    func presentIfDue() {
        guard shouldPresentNow() else { return }
        present()
    }

    private func present() {
        guard !isShowing else { return }
        isShowing = true

        model.visible = false
        model.secondsUntilEnabled = 5
        buildPanels()

        for panel in panels { panel.orderFrontRegardless() }
        panels.first?.makeKeyAndOrderFront(nil)

        DispatchQueue.main.async { [weak self] in self?.model.visible = true }
        startCountdown()
    }

    private func dismiss() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        model.visible = false
        let closing = panels
        panels = []
        isShowing = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            closing.forEach { $0.orderOut(nil) }
        }
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            if self.model.secondsUntilEnabled > 0 {
                self.model.secondsUntilEnabled -= 1
            } else {
                t.invalidate()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    // MARK: - Panels

    private func buildPanels() {
        panels.forEach { $0.orderOut(nil) }
        panels = NSScreen.screens.map { makePanel(for: $0) }
    }

    private func makePanel(for screen: NSScreen) -> NSPanel {
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

        let host = NSHostingView(rootView: ChallengeView(model: model, challenge: engine.challenge))
        host.frame = NSRect(origin: .zero, size: screen.frame.size)
        panel.contentView = host
        panel.setFrame(screen.frame, display: true)
        return panel
    }
}
