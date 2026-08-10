//
//  DeskResetController.swift
//  Iris
//
//  Shows a small floating checklist panel anchored near the menu bar button.
//

import AppKit
import SwiftUI

final class DeskResetController {

    private var panel: NSPanel?

    /// True while the checklist is on screen. Read by NudgeBudget, which must
    /// not interrupt it.
    var isPresenting: Bool { panel?.isVisible == true }

    func toggle(from anchorView: NSView) {
        if let existing = panel, existing.isVisible {
            dismiss()
        } else {
            show(from: anchorView)
        }
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func show(from anchorView: NSView) {
        let panelWidth: CGFloat = 260
        let panelHeight: CGFloat = 240

        let hostView = NSHostingView(rootView: DeskResetView(onDone: { [weak self] in
            self?.dismiss()
        }))
        hostView.frame = NSRect(origin: .zero, size: CGSize(width: panelWidth, height: panelHeight))

        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: CGSize(width: panelWidth, height: panelHeight)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.contentView = hostView
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.hidesOnDeactivate = false

        // Position below the anchor view (menu bar button).
        if let screen = anchorView.window?.screen ?? NSScreen.main {
            let anchorFrame = anchorView.convert(anchorView.bounds, to: nil)
            if let windowFrame = anchorView.window?.convertToScreen(anchorFrame) {
                let x = windowFrame.midX - panelWidth / 2
                let y = windowFrame.minY - panelHeight - 4
                let clampedX = min(max(x, screen.visibleFrame.minX), screen.visibleFrame.maxX - panelWidth)
                p.setFrame(NSRect(x: clampedX, y: y, width: panelWidth, height: panelHeight), display: false)
            }
        }

        panel = p
        p.orderFrontRegardless()
    }
}
