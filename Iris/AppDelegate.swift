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

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var warningController: WarningPillController!
    private var blackoutController: BlackoutController!
    private var challengeController: ChallengeController!

    private var cancellables = Set<AnyCancellable>()
    private var previousState: TimerEngine.TimerState = .idle

    // MARK: - Launch

    private enum LaunchError: Error {
        case statusItemUnavailable
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("Iris: applicationDidFinishLaunching started")
        do {
            try performLaunch()
            NSLog("Iris: launch complete")
        } catch {
            NSLog("Iris: FATAL error during launch: \(error)")
            FileHandle.standardError.write(Data("Iris: FATAL error during launch: \(error)\n".utf8))
        }
    }

    private func performLaunch() throws {
        setupStatusItem()
        NSLog("Iris: status item created")
        guard statusItem?.button != nil else { throw LaunchError.statusItemUnavailable }

        setupPopover()
        NSLog("Iris: popover configured")

        warningController = WarningPillController(engine: engine)
        blackoutController = BlackoutController(engine: engine)
        challengeController = ChallengeController(engine: engine)
        NSLog("Iris: window controllers created")

        observeState()
        engine.start()
        NSLog("Iris: timer engine started")

        // Touch the stats engine so the daily rollover / streak check runs, and
        // fire a morning challenge if one is due at launch.
        stats.refreshForToday()
        challengeController.presentIfDue()
        NSLog("Iris: stats refreshed, challenge checked")

        // Start call detection off the launch path so the menu bar icon is
        // guaranteed to appear first; any trouble here can't block startup.
        callDetector.onChange = { [weak self] inCall in
            self?.engine.setCallActive(inCall)
        }
        DispatchQueue.main.async { [weak self] in
            self?.callDetector.start()
            NSLog("Iris: call detector started")
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = Self.symbol("eye.fill")
            button.wantsLayer = true
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
    }

    private static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Iris")
        image?.isTemplate = true
        return image
    }

    // MARK: - Popover

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)
        let root = PopoverRootView().environmentObject(engine)
        popover.contentViewController = NSHostingController(rootView: root)
        self.popover = popover
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
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
            updateIcon(symbol: "eye.fill", pulsing: false)
        case .warning:
            updateIcon(symbol: "eye.fill", pulsing: true)
            warningController.show()
        case .resting:
            updateIcon(symbol: "eye.slash.fill", pulsing: false)
            popover.performClose(nil)
            blackoutController.show()
        }

        // --- Leaving a state ---
        if previous == .warning && state != .warning {
            warningController.hide()
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
