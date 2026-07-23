//
//  BlockerController.swift
//  Iris
//
//  Presents the focus-blocker overlay on all displays. Auto-dismisses after
//  15 seconds. "Let me in (5 min)" calls a callback so FocusBlockerEngine can
//  add a temporary whitelist entry.
//

import AppKit
import SwiftUI

private final class BlockerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class BlockerController {

    private var model: BlockerOverlayModel?
    private var panels: [NSPanel] = []
    private var autoDismissTimer: Timer?
    private var pendingLetMeIn: (() -> Void)?

    private(set) var isShowing = false

    /// Called whenever the overlay is dismissed (for any reason).
    var onDismiss: (() -> Void)?

    // MARK: - Present

    func show(for item: BlockedItem, onLetMeIn: @escaping () -> Void) {
        guard !isShowing else { return }
        isShowing = true
        pendingLetMeIn = onLetMeIn

        let m = BlockerOverlayModel()
        m.blockedName = item.name
        m.onBackToWork = { [weak self] in self?.dismiss(letMeIn: false) }
        m.onLetMeIn    = { [weak self] in self?.dismiss(letMeIn: true)  }
        model = m

        buildPanels(model: m)
        for panel in panels { panel.orderFrontRegardless() }
        panels.first?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { m.visible = true }
        scheduleAutoDismiss()
    }

    // MARK: - Dismiss

    private func dismiss(letMeIn: Bool) {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil

        if letMeIn { pendingLetMeIn?() }
        pendingLetMeIn = nil

        model?.visible = false
        let closing = panels
        panels = []
        isShowing = false
        model = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            closing.forEach { $0.orderOut(nil) }
        }
        onDismiss?()
    }

    private func scheduleAutoDismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            self?.dismiss(letMeIn: false)
        }
    }

    // MARK: - Panels

    private func buildPanels(model: BlockerOverlayModel) {
        panels.forEach { $0.orderOut(nil) }
        panels = NSScreen.screens.map { makePanel(for: $0, model: model) }
    }

    private func makePanel(for screen: NSScreen, model: BlockerOverlayModel) -> NSPanel {
        let panel = BlockerPanel(
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

        let host = NSHostingView(rootView: BlockerOverlayView(model: model))
        host.frame = NSRect(origin: .zero, size: screen.frame.size)
        panel.contentView = host
        panel.setFrame(screen.frame, display: true)
        return panel
    }
}
