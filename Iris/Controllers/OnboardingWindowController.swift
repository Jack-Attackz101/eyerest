//
//  OnboardingWindowController.swift
//  Iris
//
//  Hosts the first-launch welcome flow in a real, centered, borderless
//  window (not a popover) so it can become key and take normal clicks.
//  Closing it by any means — the corner skip control or the window itself
//  closing — resolves to the same one-time completion path.
//

import AppKit
import SwiftUI

private final class KeyableOnboardingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class OnboardingWindowController: NSObject, NSWindowDelegate {

    private let engine: TimerEngine
    private var window: KeyableOnboardingWindow?
    private var didFinish = false

    /// Called exactly once when the flow ends, with the user's launch-at-login
    /// choice (defaults to `true`, this flow's preselected value, if the user
    /// never reached Step 3).
    var onComplete: ((_ launchAtLogin: Bool) -> Void)?

    init(engine: TimerEngine) {
        self.engine = engine
    }

    func show() {
        // Iris is an accessory app (no Dock icon) — a plain window can't
        // reliably become key/frontmost under that policy. Switch to .regular
        // for the duration of onboarding so this behaves like a normal window
        // (real key status, real click/keyboard handling), then switch back.
        NSApp.setActivationPolicy(.regular)

        let size = NSSize(width: 460, height: 560)
        let window = KeyableOnboardingWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.delegate = self

        let root = OnboardingView(onFinish: { [weak self] launchAtLogin in
            self?.finish(launchAtLogin: launchAtLogin)
        })
        .environmentObject(engine)

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        host.wantsLayer = true
        host.layer?.cornerRadius = 20
        host.layer?.masksToBounds = true
        window.contentView = host

        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func finish(launchAtLogin: Bool) {
        guard !didFinish else { return }
        didFinish = true
        window?.delegate = nil
        window?.close()
        window = nil
        NSApp.setActivationPolicy(.accessory)
        onComplete?(launchAtLogin)
    }

    // MARK: - NSWindowDelegate

    /// The window closing by any means (the skip control calls `close()` too)
    /// is the same "abandon onboarding" edge case — finish with the flow's
    /// current defaults.
    func windowWillClose(_ notification: Notification) {
        finish(launchAtLogin: true)
    }
}
