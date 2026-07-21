//
//  WarningPillController.swift
//  Iris
//
//  Owns the borderless, always-on-top NSPanel that hosts the warning pill and
//  positions it at the top-center of the main display.
//

import AppKit
import SwiftUI

final class WarningPillController {

    private let engine: TimerEngine
    private let model = WarningPillModel()
    private let panel: NSPanel

    /// The panel is taller than the pill so the pill has room to slide down
    /// from off-screen into its resting position.
    private let panelWidth: CGFloat = 400
    private let panelHeight: CGFloat = 120

    init(engine: TimerEngine) {
        self.engine = engine

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let host = NSHostingView(rootView: WarningPillView(model: model).environmentObject(engine))
        host.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        panel.contentView = host
    }

    func show() {
        positionPanel()
        panel.orderFrontRegardless()
        // Defer the flag flip a runloop hop so the spring animates from the
        // hidden position rather than snapping into place on first layout.
        DispatchQueue.main.async { [weak self] in
            self?.model.presented = true
        }
    }

    func hide() {
        model.presented = false
        // Order the panel out only after the exit spring has settled.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.model.presented else { return }
            self.panel.orderOut(nil)
        }
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let origin = NSPoint(
            x: frame.midX - panelWidth / 2,
            y: frame.maxY - panelHeight
        )
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: panelWidth, height: panelHeight)),
                       display: true)
    }
}
