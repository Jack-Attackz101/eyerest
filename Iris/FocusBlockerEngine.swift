//
//  FocusBlockerEngine.swift
//  Iris
//
//  Polls running apps and the frontmost browser every 3 seconds while the focus
//  blocker is enabled. On detection: hides the blocked app and triggers the
//  blocker overlay. Website blocking uses the Accessibility API to read the
//  current URL/title — gracefully inactive if permission is not granted.
//

import AppKit
import Combine

final class FocusBlockerEngine {

    // MARK: - Dependencies

    private let engine: TimerEngine
    private let blocker: BlockerController

    /// Set by AppDelegate to suppress the overlay during rest or challenge screens.
    var shouldSuppress: (() -> Bool)?

    // MARK: - State

    private var pollTimer: Timer?
    private var tempWhitelist: [UUID: Date] = [:]
    private var overlayActive = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Browser detection

    private static let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "com.kagi.kagimacOS",
    ]

    // MARK: - Init

    init(engine: TimerEngine, blocker: BlockerController) {
        self.engine = engine
        self.blocker = blocker

        blocker.onDismiss = { [weak self] in
            self?.overlayActive = false
        }
    }

    // MARK: - Lifecycle

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidLaunch),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        engine.$focusBlockerEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in self?.onEnabledChanged(enabled) }
            .store(in: &cancellables)

        if engine.focusBlockerEnabled { startPolling() }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Enable / disable

    private func onEnabledChanged(_ enabled: Bool) {
        if enabled {
            startPolling()
        } else {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkAll()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    // MARK: - App launch hook (instant detection)

    @objc private func appDidLaunch(_ notification: Notification) {
        guard engine.focusBlockerEnabled else { return }
        checkApps()
    }

    // MARK: - Detection

    private func checkAll() {
        checkApps()
        checkBrowser()
    }

    private func checkApps() {
        let running = NSWorkspace.shared.runningApplications
        for item in enabledItems(kind: .app) {
            guard let bundleID = item.bundleID, !isWhitelisted(item) else { continue }
            if let app = running.first(where: { $0.bundleIdentifier == bundleID }) {
                app.hide()
                triggerOverlay(for: item)
            }
        }
    }

    private func checkBrowser() {
        guard AXIsProcessTrusted() else { return }
        guard let front = NSWorkspace.shared.frontmostApplication,
              Self.browserBundleIDs.contains(front.bundleIdentifier ?? "") else { return }

        guard let text = readBrowserText(pid: front.processIdentifier) else { return }
        let lowered = text.lowercased()

        for item in enabledItems(kind: .website) {
            guard let domain = item.domain, !isWhitelisted(item) else { continue }
            if lowered.contains(domain.lowercased()) {
                triggerOverlay(for: item)
                return
            }
        }
    }

    // MARK: - Overlay trigger

    private func triggerOverlay(for item: BlockedItem) {
        guard !overlayActive else { return }
        guard !(shouldSuppress?() ?? false) else { return }
        overlayActive = true

        let capturedItem = item
        blocker.show(for: item) { [weak self] in
            // "Let me in (5 min)": whitelist for 5 minutes.
            self?.tempWhitelist[capturedItem.id] = Date().addingTimeInterval(5 * 60)
        }
    }

    // MARK: - Whitelist

    private func isWhitelisted(_ item: BlockedItem) -> Bool {
        guard let expiry = tempWhitelist[item.id] else { return false }
        if Date() > expiry {
            tempWhitelist.removeValue(forKey: item.id)
            return false
        }
        return true
    }

    // MARK: - AX browser URL reading

    private func readBrowserText(pid: pid_t) -> String? {
        let axApp = AXUIElementCreateApplication(pid)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef else { return nil }

        let axWindow = windowRef as! AXUIElement  // CFTypeRef from AX API — always an AXUIElement here

        // Try AXDocument: Safari and some browsers expose the page URL here.
        var docRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axWindow, "AXDocument" as CFString, &docRef) == .success,
           let doc = docRef as? String { return doc }

        // Fallback: window title contains the page title (e.g. "YouTube — Google Chrome").
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success {
            return titleRef as? String
        }

        return nil
    }

    // MARK: - Accessibility permission prompt

    /// Shows a friendly NSAlert then opens the System Settings AX prompt if the
    /// user agrees. Call when a website item is added or the blocker is first enabled
    /// with website items already present.
    func requestAXPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        guard engine.blockedItems.contains(where: { $0.kind == .website && $0.isEnabled }) else { return }

        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "To detect blocked websites, Iris needs Accessibility access. Iris never stores or transmits what it sees."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn {
            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary)
        }
    }

    // MARK: - Helpers

    private func enabledItems(kind: BlockedItem.Kind) -> [BlockedItem] {
        engine.blockedItems.filter { $0.isEnabled && $0.kind == kind }
    }
}
