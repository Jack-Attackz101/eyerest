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

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let engine = TimerEngine.shared
    private let stats = StatsEngine.shared
    private let sound = SoundManager()
    private let ambient = AmbientPlayer()
    private let callDetector = CallDetector()
    private let dashboard = DashboardState()

    private var statusItem: NSStatusItem!
    private var dashboardPanel: DashboardPanelController!
    private var warningController: WarningPillController!
    private var blackoutController: BlackoutController!
    private var challengeController: ChallengeController!
    private var onboarding: OnboardingWindowController?

    private var cancellables = Set<AnyCancellable>()
    private var previousState: TimerEngine.TimerState = .idle

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
            // Only ever logged on an actual launch failure, not during normal runs.
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

        observeState()

        // First launch ever: walk the user through onboarding before the timer
        // starts. Every launch after: silent, timer starts immediately.
        if UserDefaults.standard.bool(forKey: OnboardingKeys.hasCompleted) {
            completeLaunchSequence()
        } else {
            showOnboarding()
        }
    }

    /// Everything that happens once the timer is actually allowed to run —
    /// either right away (onboarding already completed on a prior launch) or
    /// once the first-launch welcome flow finishes.
    private func completeLaunchSequence() {
        engine.start()

        // Daily rollover / streak check, plus a morning challenge if due.
        stats.refreshForToday()
        challengeController.presentIfDue()

        // Start call detection off the launch path so the menu bar icon always
        // appears first and detection can never block startup.
        callDetector.onChange = { [weak self] inCall in
            self?.engine.setCallActive(inCall)
        }
        DispatchQueue.main.async { [weak self] in
            self?.callDetector.start()
        }
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

    /// Testing/debug re-entry point (Option-click the menu bar icon). Purely
    /// cosmetic — the app is already running, so completion just closes the
    /// window; it does not touch the onboarding flag or restart anything.
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
        // Always an SF Symbol template — never the AppIcon — so it renders as a
        // crisp, correctly-sized, light/dark-adaptive menu bar glyph.
        button.image = Self.symbol("eye")
        button.wantsLayer = true
        button.target = self
        button.action = #selector(togglePopover)
    }

    /// A 16pt template SF Symbol for the menu bar.
    private static func symbol(_ name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Iris")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    // MARK: - Popover (cinematic dashboard panel)

    @objc private func togglePopover() {
        guard let button = statusItem.button else {
            FileHandle.standardError.write(Data("Iris: status item button unavailable\n".utf8))
            return
        }
        if NSEvent.modifierFlags.contains(.option) {
            showDebugMenu(from: button)
            return
        }
        dashboardPanel.toggle(from: button)
    }

    /// Hidden testing entry point: Option-click the menu bar icon to re-show
    /// the welcome flow without affecting the persisted onboarding flag.
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
}
