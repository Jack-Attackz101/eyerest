//
//  WarningPillController.swift
//  Iris
//
//  Owns the borderless, always-on-top NSPanel hosting the warning pill. On notch
//  Macs the panel sits flush with the top edge, centered on the notch, so the
//  pill appears to grow out of it; otherwise it floats at the top-center.
//

import AppKit
import SwiftUI

final class WarningPillController {

    private let engine: TimerEngine
    private let model = WarningPillModel()
    private let panel: NSPanel
    private let host: NSHostingView<AnyView>

    private let panelWidth: CGFloat = 360
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
        panel.hasShadow = false           // a window shadow would break the notch illusion
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        host = NSHostingView(rootView: AnyView(WarningPillView(model: model).environmentObject(engine)))
        host.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
    }

    func show() {
        model.hasNotch = Self.currentScreenHasNotch()
        model.expanded = false
        positionPanel()
        panel.orderFrontRegardless()
        // Flip to expanded a runloop hop later so the spring animates from the
        // collapsed (notch-sized / off-screen) state.
        DispatchQueue.main.async { [weak self] in
            self?.model.expanded = true
        }
    }

    func hide() {
        model.expanded = false
        // Order the panel out only after the collapse spring has settled.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.model.expanded else { return }
            self.panel.orderOut(nil)
        }
    }

    // MARK: - Geometry

    private static func currentScreenHasNotch() -> Bool {
        guard let screen = NSScreen.main else { return false }
        return screen.safeAreaInsets.top > 0
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        // Panel top edge flush with the physical top of the screen, centered so
        // the pill lines up with the (centered) notch.
        let origin = NSPoint(
            x: frame.midX - panelWidth / 2,
            y: frame.maxY - panelHeight
        )
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: panelWidth, height: panelHeight)),
                       display: true)
    }
}
