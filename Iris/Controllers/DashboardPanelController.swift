//
//  DashboardPanelController.swift
//  Iris
//
//  A borderless, rounded NSPanel that behaves like a popover but gives us full
//  control over the shape (radius 20, no arrow, no border) for the cinematic
//  video dashboard. Dismisses on a click outside, like a transient popover.
//

import AppKit
import SwiftUI

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class DashboardPanelController {

    private let engine: TimerEngine
    private let dashboard: DashboardState
    private let panel: KeyablePanel
    private var clickMonitor: Any?

    private let panelSize = NSSize(width: 320, height: 380)

    var isVisible: Bool { panel.isVisible }

    init(engine: TimerEngine, dashboard: DashboardState) {
        self.engine = engine
        self.dashboard = dashboard

        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = PopoverRootView()
            .environmentObject(engine)
            .environmentObject(dashboard)
        let host = NSHostingView(rootView: AnyView(root))
        host.frame = NSRect(origin: .zero, size: panelSize)
        host.wantsLayer = true
        host.layer?.cornerRadius = 20
        host.layer?.masksToBounds = true
        panel.contentView = host
    }

    // MARK: - Show / hide

    func toggle(from button: NSStatusBarButton) {
        if panel.isVisible { hide() } else { show(from: button) }
    }

    func show(from button: NSStatusBarButton) {
        dashboard.popoverOpened()
        position(below: button)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startClickMonitor()
    }

    func hide() {
        guard panel.isVisible else { return }
        stopClickMonitor()
        dashboard.popoverClosed()
        panel.orderOut(nil)
    }

    // MARK: - Positioning

    private func position(below button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let rectInWindow = button.convert(button.bounds, to: nil)
        let rectOnScreen = buttonWindow.convertToScreen(rectInWindow)

        var x = rectOnScreen.midX - panelSize.width / 2
        let y = rectOnScreen.minY - panelSize.height - 4

        // Keep the panel fully on the active screen.
        if let screen = button.window?.screen ?? NSScreen.main {
            let minX = screen.visibleFrame.minX + 8
            let maxX = screen.visibleFrame.maxX - panelSize.width - 8
            x = min(max(x, minX), maxX)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Click-outside dismissal

    private func startClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            // Global monitor only fires for clicks outside this app → dismiss.
            self?.hide()
        }
    }

    private func stopClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}
