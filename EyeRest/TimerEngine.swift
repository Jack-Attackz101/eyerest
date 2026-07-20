//
//  TimerEngine.swift
//  EyeRest
//
//  The single source of truth for the 20-20-20 cycle. Owns the countdown,
//  the state machine, persisted settings, sleep/wake handling and launch-at-login.
//

import Foundation
import Combine
import AppKit
import ServiceManagement

final class TimerEngine: ObservableObject {

    /// Shared singleton. The whole app observes this one instance.
    static let shared = TimerEngine()

    // MARK: - State machine

    enum TimerState {
        case idle       // Not yet started.
        case counting   // Counting down toward the next break.
        case warning    // Inside the warning window; the pill HUD is visible.
        case resting    // Blackout overlay is up; the eyes rest.
    }

    // MARK: - Published runtime state

    @Published private(set) var timerState: TimerState = .idle
    @Published private(set) var timeRemaining: TimeInterval = 0
    @Published private(set) var restTimeRemaining: Int = 0
    @Published private(set) var isPaused: Bool = false

    // MARK: - Persisted settings

    @Published var intervalMinutes: Int {
        didSet { defaults.set(intervalMinutes, forKey: Keys.interval) }
    }
    @Published var warningMinutes: Int {
        didSet { defaults.set(warningMinutes, forKey: Keys.warning) }
    }
    @Published var restDuration: Int {
        didSet { defaults.set(restDuration, forKey: Keys.rest) }
    }
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.sound) }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launch)
            applyLoginItemState()
        }
    }

    // MARK: - Private

    private let defaults = UserDefaults.standard
    private var timer: Timer?
    /// Rest duration captured at the moment a rest begins, so mid-rest setting
    /// changes are buffered and only take effect on the next cycle.
    private var activeRestDuration: Int = 20
    /// Remembers whether the timer was already paused before the machine slept,
    /// so waking doesn't accidentally un-pause a user-paused timer.
    private var pausedBeforeSleep = false
    /// Guards the reflection of the real login-item registration state back into
    /// `launchAtLogin` so it doesn't recurse through the property's `didSet`.
    private var isSyncingLoginItem = false

    /// Seconds represented by one "minute" of interval/warning. Normally 60;
    /// the debug fast-cycle flag collapses it to 1 so a whole cycle runs in
    /// seconds. (Rest duration is always in real seconds and isn't scaled.)
    private var unitMultiplier: Int { DebugConfig.fastCycle ? 1 : 60 }

    private enum Keys {
        static let interval = "intervalMinutes"
        static let warning = "warningMinutes"
        static let rest = "restDuration"
        static let sound = "soundEnabled"
        static let launch = "launchAtLogin"
    }

    private init() {
        defaults.register(defaults: [
            Keys.interval: 20,
            Keys.warning: 2,
            Keys.rest: 20,
            Keys.sound: true,
            Keys.launch: false,
        ])

        intervalMinutes = Self.clamp(defaults.integer(forKey: Keys.interval), 5...120)
        warningMinutes = Self.clamp(defaults.integer(forKey: Keys.warning), 1...5)
        restDuration = Self.clamp(defaults.integer(forKey: Keys.rest), 10...60)
        soundEnabled = defaults.bool(forKey: Keys.sound)
        launchAtLogin = defaults.bool(forKey: Keys.launch)

        // Reflect the real registration state (the user may have changed it in
        // System Settings) without kicking off another register/unregister.
        syncLoginItemStateFromSystem()
        registerSleepWakeObservers()
    }

    // MARK: - Lifecycle

    /// Begin the very first countdown. Called once at launch.
    func start() {
        beginCounting()
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - The one-second heartbeat

    private func tick() {
        guard !isPaused else { return }

        switch timerState {
        case .counting, .warning:
            timeRemaining -= 1
            if timeRemaining <= 0 {
                beginRest()
            } else if timerState == .counting && timeRemaining <= Double(warningMinutes * unitMultiplier) {
                timerState = .warning
            }

        case .resting:
            restTimeRemaining -= 1
            if restTimeRemaining <= 0 {
                endRest()
            }

        case .idle:
            break
        }
    }

    // MARK: - Transitions

    private func beginCounting() {
        isPaused = false
        timeRemaining = Double(intervalMinutes * unitMultiplier)
        timerState = .counting
    }

    private func beginRest() {
        activeRestDuration = restDuration
        restTimeRemaining = restDuration
        timerState = .resting
    }

    private func endRest() {
        beginCounting()
    }

    // MARK: - User actions

    /// Skip straight to a rest. Ignored if already resting (debounces rapid
    /// double-taps of "Rest Now").
    func restNow() {
        guard timerState != .resting else { return }
        isPaused = false
        beginRest()
    }

    /// Toggle pause/resume. The state itself is preserved; only the countdown halts.
    func togglePause() {
        isPaused.toggle()
    }

    // MARK: - Display helpers

    /// Time remaining as MM:SS, zero-padded (main countdown ring).
    var formattedTimeRemaining: String {
        let total = max(0, Int(timeRemaining))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// Time remaining as M:SS (warning pill, e.g. "1:45").
    var warningFormattedTime: String {
        let total = max(0, Int(timeRemaining))
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    /// Fraction of the current interval that has already elapsed (0...1).
    var intervalElapsedFraction: Double {
        let total = Double(intervalMinutes * unitMultiplier)
        guard total > 0 else { return 0 }
        return min(1, max(0, (total - timeRemaining) / total))
    }

    /// Fraction of the warning window still remaining (0...1).
    var warningFraction: Double {
        let total = Double(warningMinutes * unitMultiplier)
        guard total > 0 else { return 0 }
        return min(1, max(0, timeRemaining / total))
    }

    /// Fraction of the rest still remaining (0...1).
    var restFraction: Double {
        let total = Double(activeRestDuration)
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(restTimeRemaining) / total))
    }

    // MARK: - Sleep / wake

    private func registerSleepWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self,
                           selector: #selector(handleWillSleep),
                           name: NSWorkspace.willSleepNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleDidWake),
                           name: NSWorkspace.didWakeNotification,
                           object: nil)
    }

    @objc private func handleWillSleep() {
        pausedBeforeSleep = isPaused
        isPaused = true
    }

    @objc private func handleDidWake() {
        // Only resume if the user hadn't already paused it themselves.
        isPaused = pausedBeforeSleep
    }

    // MARK: - Launch at login

    private func syncLoginItemStateFromSystem() {
        let enabled = SMAppService.mainApp.status == .enabled
        if enabled != launchAtLogin {
            isSyncingLoginItem = true
            launchAtLogin = enabled
            isSyncingLoginItem = false
        }
    }

    private func applyLoginItemState() {
        guard !isSyncingLoginItem else { return }
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Registration failed — reflect the true state back into the toggle.
            NSLog("EyeRest: launch-at-login update failed: \(error.localizedDescription)")
            syncLoginItemStateFromSystem()
        }
    }

    // MARK: - Utility

    private static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
