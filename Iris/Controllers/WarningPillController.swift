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

/// A panel that is allowed to sit over the menu bar.
///
/// AppKit constrains every window's frame so it does not cover the menu bar,
/// silently, by clamping to the screen's visible frame. So positioning the panel
/// at `screen.frame.maxY - height` was not enough: the frame came back moved
/// down by the menu bar height, which is where most of the strip above the pill
/// came from. Measured on a 1470x956 screen, the panel asked for y 912 and was
/// given 879, exactly the 33pt the menu bar occupies.
private final class PillPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

final class WarningPillController {

    private let engine: TimerEngine
    private let model = WarningPillModel()
    private let panel: PillPanel
    private let host: NSHostingView<AnyView>
    /// Last logged geometry signature, so the diagnostic prints once rather than
    /// on every warning window.
    private var lastGeometryLog = ""

    init(engine: TimerEngine) {
        self.engine = engine

        panel = PillPanel(
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

    /// The panel is exactly the pill. It used to be 260x56 for the non-notch
    /// case, 56 being "8pt gap + 44pt pill + 4pt margin", so even with the panel
    /// flush against the top the pill inside it was not.
    private var panelSize: NSSize {
        model.hasNotch
            ? NSSize(width: model.notchWidth + PillMetrics.sideExt * 2 + PillMetrics.snoozeW,
                     height: PillMetrics.pillH)
            : NSSize(width: PillMetrics.fallW + PillMetrics.snoozeW, height: PillMetrics.pillH)
    }

    /// The screen the pill belongs on.
    ///
    /// `NSScreen.main` is whichever screen currently holds the key window, not
    /// the built-in display. On a Mac plugged into an external monitor, if the
    /// focused window was on the external screen then `detectGeometry()` read
    /// that screen's `safeAreaInsets.top`, got 0, and the pill rendered narrow on
    /// the external monitor instead of wrapping the notch. Prefer a screen that
    /// actually has a notch. The pill is flush either way now, so getting this
    /// wrong costs the notch-width sizing rather than the whole look.
    private var pillScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
    }

    private func detectGeometry() {
        guard let screen = pillScreen else {
            model.hasNotch = false
            logGeometry(screen: nil)
            return
        }
        let top = screen.safeAreaInsets.top
        if top > 0 {
            model.hasNotch = true
            model.notchHeight = top
            let leftW = screen.auxiliaryTopLeftArea?.width ?? 0
            let rightW = screen.auxiliaryTopRightArea?.width ?? 0
            let notchW = screen.frame.width - leftW - rightW
            model.notchWidth = notchW > 40 ? notchW : 200
        } else {
            // No notch. The pill is a plain tab hanging off the top edge, and
            // hasNotch now decides its width and nothing else.
            model.hasNotch = false
        }
        logGeometry(screen: screen)
    }

    /// What was detected, once, so it is possible to tell from the outside which
    /// branch ran. There was no way to do that when the pill came out wrong on
    /// Jack's machine, which is why the cause was guessed at rather than read.
    /// Logged again only if the answer changes, for example on a display change.
    private func logGeometry(screen: NSScreen?) {
        guard let screen else {
            if lastGeometryLog != "no-screen" {
                lastGeometryLog = "no-screen"
                NSLog("Iris pill: no screen available, falling back to no notch")
            }
            return
        }
        let signature = "\(screen.localizedName)|\(NSStringFromRect(screen.frame))|\(screen.safeAreaInsets.top)|\(model.hasNotch)"
        guard signature != lastGeometryLog else { return }
        lastGeometryLog = signature
        NSLog("""
              Iris pill geometry: screen \"%@\", frame %@, safeAreaInsets.top %.1f, \
              hasNotch %@, pill %@
              """,
              screen.localizedName,
              NSStringFromRect(screen.frame),
              screen.safeAreaInsets.top,
              model.hasNotch ? "true" : "false",
              NSStringFromSize(panelSize))
    }

    private func positionPanel() {
        guard let screen = pillScreen else { return }
        let size = panelSize
        // Flush with the physical top of the display: frame, never visibleFrame,
        // because visibleFrame stops below the menu bar and that is exactly the
        // gap this pill is not supposed to have.
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
