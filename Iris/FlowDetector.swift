//
//  FlowDetector.swift
//  Iris
//
//  Decides whether *right now* is a bad moment to interrupt.
//
//  Why this exists: the single most common complaint about every break reminder
//  on the market is that it blacks the screen out mid-sentence. Iris has no skip
//  button, which is a deliberate choice, but "no skip" is only defensible if the
//  break does not arrive at a stupid moment in the first place. Without this,
//  the two decisions combine into the worst possible pairing: it interrupts you
//  mid-flow AND you cannot dismiss it.
//
//  Two signals, both cheap:
//
//    1. Typing. If keys are landing right now you are mid-thought. Uses a global
//       event monitor, which needs Accessibility. Without that permission this
//       signal is simply reported as false rather than guessed at, so behaviour
//       degrades to exactly what it was before.
//
//    2. Fullscreen. A frontmost window covering the whole screen is usually a
//       presentation, a video call, a film, or a game. Detected via window
//       geometry rather than a bundle-id list, so it does not need updating
//       every time a new app ships.
//
//  Calls are deliberately NOT handled here. CallDetector already owns that and
//  suspends the countdown outright, which is a stronger response than deferral.
//
//  This only ever DELAYS a break, and TimerEngine caps how long for. It can
//  never cancel one, otherwise a busy day would silently mean no breaks at all,
//  which is the failure mode that makes these apps worthless.
//

import AppKit

final class FlowDetector {

    static let shared = FlowDetector()

    // MARK: - Tuning

    /// A keystroke within this window counts as "still typing".
    private let typingWindow: TimeInterval = 4

    // MARK: - State

    private var eventMonitor: Any?
    private var lastKeyDate: Date?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        // Only the global monitor needs Accessibility. If it is not granted we
        // still report fullscreen correctly, so half the feature keeps working.
        guard AXIsProcessTrusted(), eventMonitor == nil else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            self?.lastKeyDate = Date()
        }
    }

    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        lastKeyDate = nil
    }

    // MARK: - Signals

    /// True when a key landed within the last few seconds.
    var isTyping: Bool {
        guard let last = lastKeyDate else { return false }
        return Date().timeIntervalSince(last) < typingWindow
    }

    /// True when the frontmost window covers an entire screen.
    ///
    /// Compared against `screen.frame` rather than `visibleFrame`, because a
    /// true fullscreen window covers the menu bar and the Dock, which is
    /// precisely what distinguishes it from a merely maximised window.
    var isFullscreenAppFrontmost: Bool {
        guard let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return false
        }

        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for window in windows {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pid == frontPID,
                  let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }

            for screen in NSScreen.screens where bounds.size == screen.frame.size {
                return true
            }
        }

        return false
    }

    /// Whether Iris should hold a break back for a moment.
    var isInFlow: Bool {
        isTyping || isFullscreenAppFrontmost
    }

    /// Human-readable reason, for the menu bar tooltip and for debugging.
    var reason: String? {
        if isFullscreenAppFrontmost { return "waiting, fullscreen app in front" }
        if isTyping { return "waiting for you to stop typing" }
        return nil
    }
}
