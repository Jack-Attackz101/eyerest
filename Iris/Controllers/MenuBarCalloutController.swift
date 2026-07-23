//
//  MenuBarCalloutController.swift
//  Iris
//
//  Shows a brief, non-interactive arrow + label above the status item so a
//  first-time user finds the menu bar icon right after onboarding, and pulses
//  the icon itself a few times. Purely decorative — ignores all mouse events
//  and auto-dismisses.
//

import AppKit
import SwiftUI

enum MenuBarCalloutController {

    /// Pulses the status item's icon opacity 3 times and shows a small
    /// "Iris is here" arrow above it for a couple of seconds.
    static func present(for button: NSStatusBarButton) {
        pulseIcon(button)
        showCallout(above: button)
    }

    private static func pulseIcon(_ button: NSStatusBarButton) {
        guard let layer = button.layer else { return }
        layer.removeAnimation(forKey: "onboardingPulse")
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.3
        pulse.duration = 0.35
        pulse.autoreverses = true
        pulse.repeatCount = 3
        layer.add(pulse, forKey: "onboardingPulse")
    }

    private static func showCallout(above button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }

        let size = NSSize(width: 100, height: 50)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let host = NSHostingView(rootView: MenuBarCalloutView())
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host

        let rectInWindow = button.convert(button.bounds, to: nil)
        let rectOnScreen = buttonWindow.convertToScreen(rectInWindow)
        let x = rectOnScreen.midX - size.width / 2
        let y = rectOnScreen.minY - size.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
    }
}
