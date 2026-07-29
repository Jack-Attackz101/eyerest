//
//  WindDownController.swift
//  Iris
//
//  Manages the 60-second end-of-day wind-down overlay panel.
//

import AppKit
import SwiftUI

final class WindDownController {

    private let engine: TimerEngine
    private let model = WindDownModel()
    private var panels: [NSPanel] = []
    private var countdownTimer: Timer?
    private var phaseTimer: Timer?
    private var phaseSecondsLeft: Int = 0
    private var isActive = false

    init(engine: TimerEngine) {
        self.engine = engine
    }

    // MARK: - Show / hide

    func show() {
        guard !isActive else { return }
        isActive = true

        model.secondsRemaining = 60
        model.phase = .inhale

        // Pause the work timer while winding down.
        if !engine.isPaused { engine.togglePause() }

        buildPanels()
        DispatchQueue.main.async { [weak self] in
            self?.model.visible = true
        }

        startCountdown()
        startBreathCycle()
    }

    func hide() {
        guard isActive else { return }
        isActive = false
        model.visible = false
        countdownTimer?.invalidate(); countdownTimer = nil
        phaseTimer?.invalidate(); phaseTimer = nil

        // Resume the timer if it was paused by wind-down.
        if engine.isPaused { engine.togglePause() }

        let closing = panels
        panels = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            closing.forEach { $0.orderOut(nil) }
        }
    }

    // MARK: - Countdown

    private func startCountdown() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.model.secondsRemaining -= 1
            if self.model.secondsRemaining <= 0 {
                self.hide()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        countdownTimer = t
    }

    // MARK: - Breath cycle

    private func startBreathCycle() {
        phaseSecondsLeft = model.phase.duration
        schedulePhaseStep()
    }

    private func schedulePhaseStep() {
        phaseTimer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.phaseStep()
        }
        RunLoop.main.add(t, forMode: .common)
        phaseTimer = t
    }

    private func phaseStep() {
        guard isActive else { return }
        phaseSecondsLeft -= 1
        if phaseSecondsLeft <= 0 {
            model.phase = model.phase.next
            phaseSecondsLeft = model.phase.duration
        }
        schedulePhaseStep()
    }

    // MARK: - Panels

    private func buildPanels() {
        panels.forEach { $0.orderOut(nil) }
        panels = NSScreen.screens.map { makePanel(for: $0) }
        panels.forEach { $0.orderFrontRegardless() }
        panels.first?.makeKeyAndOrderFront(nil)
    }

    private func makePanel(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false

        let host = NSHostingView(rootView: WindDownView(model: model, onDismiss: { [weak self] in
            self?.hide()
        }))
        host.frame = NSRect(origin: .zero, size: screen.frame.size)
        panel.contentView = host
        panel.setFrame(screen.frame, display: true)
        return panel
    }
}
