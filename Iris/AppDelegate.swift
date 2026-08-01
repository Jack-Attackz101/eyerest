//
//  AppDelegate.swift
//  Iris
//
//  Wires everything together: the menu bar status item + popover, the warning
//  pill HUD, the blackout overlays and the sound cues. It observes the shared
//  TimerEngine's state and reacts to every transition.
//

import Cocoa
import Combine
import SwiftUI

/// How long a transient menu-bar nudge stays visible before the icon returns.
private let nudgeDisplaySeconds: TimeInterval = 6

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let engine = TimerEngine.shared
    private let stats = StatsEngine.shared
    private let sound = SoundManager()
    private let ambient = AmbientPlayer()
    private let callDetector = CallDetector()
    private let dashboard = DashboardState()
    private let nudgeEngine = NudgeEngine()

    // V3 feature engines
    private let waterEngine = WaterReminderEngine()
    private let standUpEngine = StandUpEngine()
    private let wristReliefEngine = WristReliefEngine()
    private let scrollFatigueEngine = ScrollFatigueEngine()

    private var statusItem: NSStatusItem!
    private var dashboardPanel: DashboardPanelController!
    private var warningController: WarningPillController!
    private var blackoutController: BlackoutController!
    private var challengeController: ChallengeController!
    private var blockerController: BlockerController!
    private var focusBlockerEngine: FocusBlockerEngine!
    private var windDownController: WindDownController!
    private var deskResetController: DeskResetController!
    private var onboarding: OnboardingWindowController?
    private var licenseWindow: LicenseWindowController?

    private var cancellables = Set<AnyCancellable>()
    private var previousState: TimerEngine.TimerState = .idle

    // Tracks whether the status item is currently displaying nudge text.
    private var isShowingNudge = false
    // Generation counter — invalidates in-flight completion handlers when a
    // new nudge or revert animation starts before the previous one finishes.
    private var nudgeAnimGen = 0

    // Late-night guard: fire the wrap-up nudge only once per session.
    private var lateNightNudgeFired = false
    // Brightness check timer.
    private var brightnessCheckTimer: Timer?
    // Track call start time for post-meeting reset.
    private var callStartDate: Date?

    private enum OnboardingKeys {
        static let hasCompleted = "iris.hasCompletedOnboarding"
    }

    // MARK: - Launch

    private enum LaunchError: Error {
        case statusItemUnavailable
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try performLaunch()
        } catch {
            FileHandle.standardError.write(Data("Iris: launch failed: \(error)\n".utf8))
        }
    }

    private func performLaunch() throws {
        setupStatusItem()
        guard statusItem?.button != nil else { throw LaunchError.statusItemUnavailable }

        dashboardPanel = DashboardPanelController(engine: engine, dashboard: dashboard)

        warningController = WarningPillController(engine: engine)
        blackoutController = BlackoutController(engine: engine)
        challengeController = ChallengeController(engine: engine)
        blockerController = BlockerController()
        focusBlockerEngine = FocusBlockerEngine(engine: engine, blocker: blockerController)
        windDownController = WindDownController(engine: engine)
        deskResetController = DeskResetController()

        observeState()

        if UserDefaults.standard.bool(forKey: OnboardingKeys.hasCompleted) {
            completeLaunchSequence()
        } else {
            showOnboarding()
        }
    }

    private func completeLaunchSequence() {
        guard LicenseManager.shared.canRun else {
            showLicenseWindow()
            return
        }
        engine.start()
        Task { @MainActor in UpdateChecker.shared.start() }

        stats.refreshForToday()
        challengeController.presentIfDue()

        callDetector.onChange = { [weak self] inCall in
            self?.engine.setCallActive(inCall)
        }
        DispatchQueue.main.async { [weak self] in
            self?.callDetector.start()
        }

        nudgeEngine.onShow = { [weak self] text in self?.beginNudge(text) }
        nudgeEngine.onHide = { [weak self] in self?.endNudge(animated: true) }
        nudgeEngine.start()

        focusBlockerEngine.shouldSuppress = { [weak self] in
            guard let self else { return false }
            return challengeController.isPresenting || engine.timerState == .resting
        }
        focusBlockerEngine.start()

        // MARK: V3 features

        // Feature 2: Water reminders
        waterEngine.onNudge = { [weak self] in
            self?.showTransientNudge("drink some water")
        }
        waterEngine.start()

        // Feature 4: Stand-up mode
        standUpEngine.onNudge = { [weak self] in
            self?.showTransientNudge("time to stand up")
        }
        standUpEngine.start()

        // Feature 5: Late-night guard — show wrap-up nudge when first activated.
        engine.$isInLateNight
            .receive(on: RunLoop.main)
            .sink { [weak self] inLateNight in
                guard let self else { return }
                if inLateNight && !self.lateNightNudgeFired {
                    self.lateNightNudgeFired = true
                    self.showTransientNudge("time to wrap up")
                }
                if !inLateNight { self.lateNightNudgeFired = false }
            }
            .store(in: &cancellables)

        // Feature 6: Brightness check — periodic nudge during late-night window.
        startBrightnessCheckTimer()

        // Feature 9: Wrist relief timer
        wristReliefEngine.onNudge = { [weak self] in
            self?.showTransientNudge("shake out your wrists")
        }
        wristReliefEngine.start()

        // Feature 10: Post-meeting reset
        engine.onLongCallEnded = { [weak self] in
            self?.showTransientNudge("look away — 20 seconds")
        }

        // Feature 11: Scroll fatigue
        scrollFatigueEngine.onNudge = { [weak self] in
            self?.showTransientNudge("rest your wrists")
        }
        scrollFatigueEngine.start()

        // Feature 12: Posture camera
        Task { @MainActor in
            PostureCameraEngine.shared.onPostureAlert = { [weak self] in
                self?.showTransientNudge("sit up straight")
            }
            if engine.postureCameraEnabled {
                PostureCameraEngine.shared.start()
            }
        }

        // Feature 7 & 8: Wind-down and Desk-reset buttons in MainView
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleWindDownRequested),
            name: .irisWindDownRequested, object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleDeskResetRequested),
            name: .irisDeskResetRequested, object: nil)

#if DEBUG
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleDemoNudge(_:)),
            name: .irisDemoNudge, object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleDemoChallenge),
            name: .irisDemoChallenge, object: nil)
#endif
    }

    // MARK: - License gate

    private func showLicenseWindow() {
        let controller = LicenseWindowController()
        controller.onActivated = { [weak self] in
            self?.licenseWindow = nil
            self?.completeLaunchSequence()
        }
        licenseWindow = controller
        controller.show()
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let controller = OnboardingWindowController(engine: engine)
        controller.onComplete = { [weak self] launchAtLogin in
            guard let self else { return }
            UserDefaults.standard.set(true, forKey: OnboardingKeys.hasCompleted)
            self.engine.launchAtLogin = launchAtLogin
            self.completeLaunchSequence()
            if let button = self.statusItem.button {
                MenuBarCalloutController.present(for: button)
            }
        }
        onboarding = controller
        controller.show()
    }

    private func showWelcomeGuideAgain() {
        let controller = OnboardingWindowController(engine: engine)
        controller.onComplete = { [weak self] _ in
            self?.onboarding = nil
        }
        onboarding = controller
        controller.show()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = Self.symbol("eye")
        button.wantsLayer = true
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// A 16pt template SF Symbol for the menu bar.
    private static func symbol(_ name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Iris")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        guard let button = statusItem.button else {
            FileHandle.standardError.write(Data("Iris: status item button unavailable\n".utf8))
            return
        }
        if NSApp.currentEvent?.type == .rightMouseUp {
            showHelpMenu(from: button)
            return
        }
        if isShowingNudge {
            nudgeEngine.skipCurrentNudge()
            endNudge(animated: false)
        }
        if NSEvent.modifierFlags.contains(.option) {
            showDebugMenu(from: button)
            return
        }
        dashboardPanel.toggle(from: button)
    }

    private func showHelpMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let bugItem = NSMenuItem(title: "Report a Bug", action: #selector(openBugReport), keyEquivalent: "")
        bugItem.target = self
        menu.addItem(bugItem)
        let featureItem = NSMenuItem(title: "Request a Feature", action: #selector(openFeatureRequest), keyEquivalent: "")
        featureItem.target = self
        menu.addItem(featureItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func openBugReport() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let encoded = version.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? version
        guard let url = URL(string: "https://github.com/Jack-Attackz101/eyerest/issues/new?template=bug_report.yml&iris-version=\(encoded)") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openFeatureRequest() {
        guard let url = URL(string: "https://github.com/Jack-Attackz101/eyerest/issues/new?template=feature_request.yml") else { return }
        NSWorkspace.shared.open(url)
    }

    private func showDebugMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Show Welcome Guide", action: #selector(showWelcomeGuideAgainAction), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func showWelcomeGuideAgainAction() {
        showWelcomeGuideAgain()
    }

    // MARK: - State observation

    private func observeState() {
        engine.$timerState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.handleStateChange(to: state)
            }
            .store(in: &cancellables)
    }

    private func handleStateChange(to state: TimerEngine.TimerState) {
        let previous = previousState

        // A nudge may only display during .counting. Cancel immediately for any
        // other state so the correct icon is shown without obstruction.
        if isShowingNudge, state != .counting {
            nudgeEngine.skipCurrentNudge()
            endNudge(animated: false)
        }

        // --- Entering a state ---
        switch state {
        case .idle, .counting, .scheduledPause:
            updateIcon(symbol: "eye", pulsing: false)
        case .warning:
            updateIcon(symbol: "eye", pulsing: true)
            warningController.show()
        case .resting:
            updateIcon(symbol: "eye.slash", pulsing: false)
            dashboardPanel.hide()
            blackoutController.show()
        }

        // --- Leaving a state ---
        if previous == .warning && state != .warning {
            warningController.collapse()
        }
        if previous == .resting && state != .resting {
            blackoutController.hide()
        }

        // --- Sound cues on transition edges ---
        if state == .warning && previous != .warning {
            sound.play(.warning, enabled: engine.soundEnabled)
        }
        if state == .resting && previous != .resting {
            sound.play(.restStart, enabled: engine.soundEnabled)
            if engine.soundEnabled && engine.ambientSoundEnabled {
                ambient.start()
            }
        }
        if previous == .resting && state != .resting {
            sound.play(.restEnd, enabled: engine.soundEnabled)
            ambient.stop()
        }

        previousState = state
    }

    // MARK: - Menu bar icon

    private func updateIcon(symbol name: String, pulsing: Bool) {
        guard !isShowingNudge else { return }
        statusItem.button?.image = Self.symbol(name)
        if pulsing { startPulse() } else { stopPulse() }
    }

    private func startPulse() {
        guard let layer = statusItem.button?.layer,
              layer.animation(forKey: "pulse") == nil else { return }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.5
        pulse.duration = 1.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        layer.add(pulse, forKey: "pulse")
    }

    private func stopPulse() {
        statusItem.button?.layer?.removeAnimation(forKey: "pulse")
    }

    // MARK: - V3 feature actions

    /// Shows a transient menu-bar nudge for 8 seconds, then auto-reverts.
    private func showTransientNudge(_ text: String) {
        beginNudge(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + nudgeDisplaySeconds) { [weak self] in
            guard let self, self.isShowingNudge else { return }
            self.endNudge(animated: true)
        }
    }

    /// Feature 6: Brightness check timer
    private func startBrightnessCheckTimer() {
        brightnessCheckTimer?.invalidate()
        let t = Timer(timeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.checkBrightness()
        }
        RunLoop.main.add(t, forMode: .common)
        brightnessCheckTimer = t
    }

    private func checkBrightness() {
        guard engine.brightnessCheckEnabled && engine.isInLateNight else { return }
        showTransientNudge("lower your brightness")
    }

    /// Feature 7: Wind-down
    @objc private func handleWindDownRequested() {
        dashboardPanel.hide()
        windDownController.show()
    }

    /// Feature 8: Desk reset
    @objc private func handleDeskResetRequested() {
        guard let button = statusItem.button else { return }
        deskResetController.toggle(from: button)
    }

#if DEBUG
    @objc private func handleDemoNudge(_ notification: Notification) {
        let text = notification.object as? String ?? "nudge"
        showTransientNudge(text)
    }

    @objc private func handleDemoChallenge() {
        challengeController.presentNow()
    }
#endif

    // MARK: - Menu bar nudge display

    private func beginNudge(_ text: String) {
        guard let button = statusItem.button else { return }
        isShowingNudge = true
        stopPulse()
        nudgeAnimGen += 1
        let gen = nudgeAnimGen
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            button.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak button] in
            guard let self, let button, self.nudgeAnimGen == gen else { return }
            button.image = nil
            button.title = ""
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.menuBarFont(ofSize: 0),
                .foregroundColor: NSColor.labelColor,
            ]
            button.attributedTitle = NSAttributedString(string: String(text.prefix(22)), attributes: attrs)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                button.animator().alphaValue = 1
            }
        })
    }

    private func endNudge(animated: Bool) {
        guard isShowingNudge else { return }
        isShowingNudge = false
        nudgeAnimGen += 1
        guard let button = statusItem.button else { return }

        let gen = nudgeAnimGen
        let restore: () -> Void = { [weak self, weak button] in
            guard let self, let button else { return }
            button.attributedTitle = NSAttributedString(string: "")
            button.title = ""
            let name = self.engine.timerState == .resting ? "eye.slash" : "eye"
            button.image = Self.symbol(name)
            let shouldPulse = self.engine.timerState == .warning
            if shouldPulse { self.startPulse() } else { self.stopPulse() }
        }

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                button.animator().alphaValue = 0
            }, completionHandler: { [weak self, weak button] in
                guard let self, let button, self.nudgeAnimGen == gen else { return }
                restore()
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.2
                    button.animator().alphaValue = 1
                }
            })
        } else {
            button.layer?.removeAllAnimations()
            button.alphaValue = 1
            restore()
        }
    }
}
