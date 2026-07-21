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
        startEventMonitor()

        // Flip visibility next runloop so the 0 -> 1 opacity fade actually plays.
        DispatchQueue.main.async { [weak self] in
            self?.model.visible = true
        }
    }

    func hide() {
        isActive = false
        model.fadeDuration = 0.8
        model.visible = false
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
