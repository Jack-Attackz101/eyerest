//
//  WarningPillController.swift
//  Iris
//
//  Owns the borderless NSPanel for the notch countdown pill: precise notch
//  geometry, flush positioning, and the show / collapse lifecycle. The pill's
//  shape and spring animations live in the SwiftUI content (WarningPillView);
//  this controller sizes and places the transparent panel that hosts it.
//

import AppKit
import SwiftUI

final class WarningPillController {

    private let engine: TimerEngine
    private let model = WarningPillModel()
    private let panel: NSPanel
    private let host: NSHostingView<AnyView>

    init(engine: TimerEngine) {
        self.engine = engine

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false                 // shadow (if any) is drawn in SwiftUI
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        host = NSHostingView(rootView: AnyView(WarningPillView(model: model).environmentObject(engine)))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
    }

    // MARK: - Show / collapse

    func show() {
        detectGeometry()
        model.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        model.flashing = false
        model.hovering = false
        model.expanded = false
        positionPanel()
        panel.orderFrontRegardless()
        // Flip to expanded next runloop so the grow spring plays from notch size.
        DispatchQueue.main.async { [weak self] in
            self?.model.expanded = true
        }
    }

    /// Finishing sequence: a brief flash, then collapse back into the notch, then order out.
    func collapse() {
        guard panel.isVisible else { return }
        if model.reduceMotion {
            model.expanded = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self, !self.model.expanded else { return }
                self.panel.orderOut(nil)
            }
            return
        }
        model.flashing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.model.flashing = false
            self?.model.expanded = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
            guard let self, !self.model.expanded else { return }
            self.panel.orderOut(nil)
        }
    }

    // MARK: - Geometry

    private var panelSize: NSSize {
        model.hasNotch
            ? NSSize(width: model.notchWidth + 110, height: 44)
            : NSSize(width: 260, height: 56)  // 56 = 8pt gap + 44pt pill + 4pt margin
    }

    private func detectGeometry() {
        guard let screen = NSScreen.main else { model.hasNotch = false; return }
        let top = screen.safeAreaInsets.top
        if top > 0 {
            model.hasNotch = true
            model.notchHeight = top
            let leftW = screen.auxiliaryTopLeftArea?.width ?? 0
            let rightW = screen.auxiliaryTopRightArea?.width ?? 0
            let notchW = screen.frame.width - leftW - rightW
            model.notchWidth = notchW > 40 ? notchW : 200
        } else {
            model.hasNotch = false
        }
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let size = panelSize
        // Panel top edge flush with the physical top of the screen, centered on
        // the (centered) notch so the pill's top lines up with the notch bottom.
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
