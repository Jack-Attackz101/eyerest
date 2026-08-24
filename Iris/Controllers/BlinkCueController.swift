//
//  BlinkCueController.swift
//  Iris
//
//  The blink cue itself: a small overlay that fades in and out over about 600ms
//  near the cursor.
//
//  Presentation matters more than timing here. The menu bar pill is far too
//  heavy for something that fires several times a minute, so this is deliberately
//  the lightest thing in the app: a soft dark lozenge with a closing eye, no
//  text to read, no click target, no sound unless that is the chosen style. It
//  should be noticeable peripherally and ignorable consciously.
//

import AppKit
import SwiftUI

// MARK: - The cue

private struct BlinkCueView: View {
    var body: some View {
        Image(systemName: "eye.slash.fill")
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.white.opacity(0.92))
            .frame(width: 46, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.black.opacity(0.62))
            )
    }
}

// MARK: - Controller

final class BlinkCueController {

    /// In and out. The brief asks for roughly 600ms end to end.
    private let fadeIn: TimeInterval = 0.22
    private let hold: TimeInterval = 0.16
    private let fadeOut: TimeInterval = 0.22

    private let panel: NSPanel
    private let sound = SoundManager()

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 46, height: 30),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        // It must never take a click, or a cue landing under the cursor would
        // swallow one.
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: BlinkCueView())
        panel.alphaValue = 0
    }

    /// Show one cue in the chosen style.
    func fire(style: BlinkStyle, soundEnabled: Bool) {
        switch style {
        case .off:
            return
        case .sound:
            sound.play(.warning, enabled: soundEnabled)
        case .overlay:
            flash()
        }
    }

    private func flash() {
        positionNearCursor()
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = fadeIn
            panel.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            guard let self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + self.hold) {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = self.fadeOut
                    self.panel.animator().alphaValue = 0
                }, completionHandler: {
                    self.panel.orderOut(nil)
                })
            }
        })
    }

    /// Just below and right of the pointer, kept inside the screen it is on, and
    /// never directly under the pointer so it cannot look like something to
    /// click.
    private func positionNearCursor() {
        let mouse = NSEvent.mouseLocation
        let size = panel.frame.size
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        var origin = NSPoint(x: mouse.x + 18, y: mouse.y - size.height - 18)

        if let frame = screen?.visibleFrame {
            origin.x = min(max(origin.x, frame.minX + 8), frame.maxX - size.width - 8)
            origin.y = min(max(origin.y, frame.minY + 8), frame.maxY - size.height - 8)
        }
        panel.setFrameOrigin(origin)
    }
}
