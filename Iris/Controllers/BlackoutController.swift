//
//  BlackoutController.swift
//  Iris
//
//  Manages one full-screen blackout NSPanel per connected display, swallows all
//  input while resting, and spawns overlays for displays that connect mid-rest.
//

import AppKit
import SwiftUI

/// A borderless panel that is allowed to become key so the local event monitor
/// can swallow keyboard input during a rest.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class BlackoutController {

    private let engine: TimerEngine
    private let model = BlackoutModel()
    private var panels: [NSPanel] = []
    private var eventMonitor: Any?
    private var isActive = false
    /// Drives the breathing lap. One timer for every display, since all the
    /// panels share one model.
    private var breathTimer: Timer?

    init(engine: TimerEngine) {
        self.engine = engine
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    // MARK: - Show / hide

    func show() {
        isActive = true
        rebuildPanels()

        model.fadeDuration = 0.6
        model.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // Resolve the theme once per break: "random each break" must not
        // reshuffle mid-rest, and every display has to agree.
        model.theme = engine.breakTheme.resolved()
        startEventMonitor()
        prepareStretchCard()
        preparePosturePrompt()
        prepareBoxBreathing()

        // Flip visibility next runloop so the 0 -> 1 opacity fade actually plays.
        DispatchQueue.main.async { [weak self] in
            self?.model.visible = true
        }
    }

    /// The stretch card, shown beside the countdown for the whole rest rather
    /// than taking the screen for the first fifteen seconds. It is chosen once
    /// per break and rotates, weighted toward the problem area the user picked.
    ///
    /// Box breathing wins when both are on. Two guided exercises at once is
    /// noise, and the breathing square is the more demanding of the two.
    private func prepareStretchCard() {
        model.showStretchCard = false
        model.stretchCard = nil
        guard engine.stretchCardsEnabled, !boxBreathingWillRun else { return }
        model.stretchCard = StretchCard.consume(for: engine.problemArea,
                                                using: UserDefaults.standard)
        // No delay and no fade: on a twenty second rest it has to be readable
        // in the first second.
        model.showStretchCard = true
    }

    /// Whether box breathing is going to take this break.
    private var boxBreathingWillRun: Bool {
        engine.boxBreathingEnabled && BoxBreathing.fits(restDuration: engine.restDuration)
    }

    /// Pick this session's posture prompt and reveal it 2s in (fade over 0.5s).
    private func preparePosturePrompt() {
        model.showPrompt = false
        guard engine.postureNudgesEnabled else {
            model.promptText = ""
            return
        }
        model.promptText = engine.consumePosturePrompt()
        // The stretch card gives a fuller instruction than the prompt does, so
        // when one is up the prompt stays out of the way.
        guard !model.showStretchCard else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, self.isActive else { return }
            self.model.showPrompt = true
        }
    }

    /// Apply the current screen-sharing policy to panels that already exist.
    func applySharingPolicy() {
        let type: NSWindow.SharingType = engine.hideFromScreenShare ? .none : .readOnly
        panels.forEach { $0.sharingType = type }
    }

    /// Box breathing, when it is on and the rest is long enough for a whole lap.
    /// A partial lap is worse than none, so short rests keep the posture prompt.
    private func prepareBoxBreathing() {
        breathTimer?.invalidate()
        breathTimer = nil
        model.breathElapsed = 0
        model.showBreathing = false

        guard boxBreathingWillRun else { return }
        // It starts with the rest now. It used to wait fifteen seconds for the
        // stretch card to finish taking over the screen, which no longer
        // happens: the two are mutually exclusive.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isActive else { return }
            self.model.showBreathing = true
            let started = Date()
            // 1/30s so the dot moves smoothly and reaches each corner on the
            // second. Under Reduce Motion the dot is not drawn, but the phase
            // word still has to change every 4 seconds, so the clock runs on.
            let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                guard let self, self.isActive else { return }
                self.model.breathElapsed = Date().timeIntervalSince(started)
            }
            RunLoop.main.add(timer, forMode: .common)
            self.breathTimer = timer
        }
    }

    func hide() {
        isActive = false
        breathTimer?.invalidate()
        breathTimer = nil
        model.showBreathing = false
        model.fadeDuration = 0.8
        model.visible = false
        model.showPrompt = false
        model.showStretchCard = false
        stopEventMonitor()

        // Tear the panels down after the fade-out completes.
        let closing = panels
        panels = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            closing.forEach { $0.orderOut(nil) }
        }
    }

    // MARK: - Panels

    private func rebuildPanels() {
        panels.forEach { $0.orderOut(nil) }
        panels = NSScreen.screens.map { makePanel(for: $0) }
        presentPanels()
    }

    private func presentPanels() {
        for panel in panels {
            panel.orderFrontRegardless()
        }
        // Make one panel key so keystrokes route to us and get swallowed.
        panels.first?.makeKeyAndOrderFront(nil)
    }

    private func makePanel(for screen: NSScreen) -> NSPanel {
        let panel = KeyablePanel(
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
        // Keep the blackout out of screen shares and recordings, unless someone
        // is deliberately demoing Iris and wants it in the frame.
        panel.sharingType = engine.hideFromScreenShare ? .none : .readOnly

        let host = NSHostingView(rootView: BlackoutView(model: model).environmentObject(engine))
        host.frame = NSRect(origin: .zero, size: screen.frame.size)
        panel.contentView = host
        panel.setFrame(screen.frame, display: true)
        return panel
    }

    // MARK: - Screen changes

    @objc private func screenParametersChanged() {
        guard isActive else { return }
        // A display connected or the arrangement changed mid-rest — rebuild so
        // every current screen is covered.
        rebuildPanels()
        model.visible = true
    }

    // MARK: - Input swallowing

    private func startEventMonitor() {
        guard eventMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
            .scrollWheel,
        ]
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { _ in
            // Returning nil discards the event.
            return nil
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
