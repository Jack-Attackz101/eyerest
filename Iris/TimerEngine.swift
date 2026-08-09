//
//  TimerEngine.swift
//  Iris
//
//  The single source of truth for the 20-20-20 cycle. Owns the countdown,
//  the state machine, persisted settings, sleep/wake handling, launch-at-login,
//  and the suspension logic for calls, quiet hours and schedule blocks.
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
        case idle            // Not yet started.
        case counting        // Counting down toward the next break.
        case warning         // Inside the warning window; the pill HUD is visible.
        case resting         // Blackout overlay is up; the eyes rest.
        case scheduledPause  // Inside an active schedule block (Feature 6).
    }

    /// What the popover should display in place of the countdown.
    enum PopoverStatus: Equatable {
        case counting
        case userPaused
        case callPaused          // auto-paused by a detected call; Resume override available
        case callRunning         // a call is active but Iris keeps running (resumed, or auto-pause off)
        case quietHours
        case scheduled(label: String, endsAt: Date)
    }

    // MARK: - Published runtime state

    @Published private(set) var timerState: TimerState = .idle
    @Published private(set) var timeRemaining: TimeInterval = 0
    @Published private(set) var restTimeRemaining: Int = 0
    @Published private(set) var isPaused: Bool = false

    @Published private(set) var isCallActive: Bool = false
    /// The user explicitly chose to keep Iris running during the current call.
    /// Reset automatically when the call ends.
    @Published private(set) var userResumedDuringCall: Bool = false
    @Published private(set) var isInQuietHours: Bool = false
    @Published private(set) var activeScheduleBlock: ScheduleBlock?

    // MARK: - Persisted settings (original)

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

    // MARK: - Persisted settings (V2)

    @Published var ambientSoundEnabled: Bool {
        didSet { defaults.set(ambientSoundEnabled, forKey: Keys.ambient) }
    }
    @Published var autoPauseDuringCalls: Bool {
        didSet { defaults.set(autoPauseDuringCalls, forKey: Keys.autoPauseCalls) }
    }

    /// Hold a break back for a moment if it would land mid-sentence.
    /// On by default: this is the behaviour people expect, and its absence is
    /// the single most cited reason people uninstall apps in this category.
    @Published var waitForNaturalGap: Bool {
        didSet { defaults.set(waitForNaturalGap, forKey: Keys.waitForGap) }
    }

    /// How long the current break has been held back, in seconds.
    @Published private(set) var deferredSeconds: Int = 0

    /// The longest a break can ever be postponed. Past this it fires regardless,
    /// because a break you can dodge indefinitely is not a break.
    static let maxDeferralSeconds = 120
    @Published var postureNudgesEnabled: Bool {
        didSet { defaults.set(postureNudgesEnabled, forKey: Keys.postureNudges) }
    }
    @Published var nudgeFrequency: NudgeFrequency {
        didSet { defaults.set(nudgeFrequency.rawValue, forKey: Keys.nudgeFrequency) }
    }
    @Published var quietHoursEnabled: Bool {
        didSet { defaults.set(quietHoursEnabled, forKey: Keys.quietEnabled) }
    }
    @Published var quietHoursStart: Date {
        didSet { defaults.set(quietHoursStart, forKey: Keys.quietStart) }
    }
    @Published var quietHoursEnd: Date {
        didSet { defaults.set(quietHoursEnd, forKey: Keys.quietEnd) }
    }
    @Published var scheduleBlocks: [ScheduleBlock] {
        didSet { saveScheduleBlocks() }
    }
    @Published var challenge: Challenge {
        didSet { saveChallenge() }
    }
    @Published var focusBlockerEnabled: Bool {
        didSet { defaults.set(focusBlockerEnabled, forKey: Keys.focusBlocker) }
    }
    @Published var blockedItems: [BlockedItem] {
        didSet { saveBlockedItems() }
    }

    // MARK: - Persisted settings (V3 — 12 new features)

    @Published var stretchCardsEnabled: Bool {
        didSet { defaults.set(stretchCardsEnabled, forKey: Keys.stretchCards) }
    }
    @Published var waterRemindersEnabled: Bool {
        didSet { defaults.set(waterRemindersEnabled, forKey: Keys.waterReminders) }
    }
    @Published var problemArea: ProblemArea {
        didSet { defaults.set(problemArea.rawValue, forKey: Keys.problemArea) }
    }
    @Published var standUpModeEnabled: Bool {
        didSet { defaults.set(standUpModeEnabled, forKey: Keys.standUpMode) }
    }
    @Published var lateNightGuardEnabled: Bool {
        didSet { defaults.set(lateNightGuardEnabled, forKey: Keys.lateNightGuard) }
    }
    @Published var lateNightHour: Int {
        didSet { defaults.set(lateNightHour, forKey: Keys.lateNightHour) }
    }
    @Published var brightnessCheckEnabled: Bool {
        didSet { defaults.set(brightnessCheckEnabled, forKey: Keys.brightnessCheck) }
    }
    @Published var windDownEnabled: Bool {
        didSet { defaults.set(windDownEnabled, forKey: Keys.windDown) }
    }
    @Published var deskResetEnabled: Bool {
        didSet { defaults.set(deskResetEnabled, forKey: Keys.deskReset) }
    }
    @Published var wristReliefEnabled: Bool {
        didSet { defaults.set(wristReliefEnabled, forKey: Keys.wristRelief) }
    }
    @Published var postMeetingResetEnabled: Bool {
        didSet { defaults.set(postMeetingResetEnabled, forKey: Keys.postMeetingReset) }
    }
    @Published var scrollFatigueEnabled: Bool {
        didSet { defaults.set(scrollFatigueEnabled, forKey: Keys.scrollFatigue) }
    }
    @Published var postureCameraEnabled: Bool {
        didSet { defaults.set(postureCameraEnabled, forKey: Keys.postureCamera) }
    }

    /// Set by WaterReminderEngine when the threshold is hit; cleared by acknowledgeWaterDrink().
    @Published var waterNudgePending: Bool = false

    /// True when the current hour is past lateNightHour (and before 5am).
    @Published private(set) var isInLateNight: Bool = false

    // MARK: - Private

    private let defaults = UserDefaults.standard
    private var timer: Timer?
    private var activeRestDuration: Int = 20
    private var pausedBeforeSleep = false
    private var isSyncingLoginItem = false
    private var scheduledEndDate: Date?
    private var callActiveDate: Date?

    private var unitMultiplier: Int { DebugConfig.fastCycle ? 1 : 60 }

    /// When late-night guard is active, use at most 15 min interval.
    private var effectiveIntervalMinutes: Int {
        guard lateNightGuardEnabled && isInLateNight else { return intervalMinutes }
        return min(15, intervalMinutes)
    }

    /// Posture prompts rotated through on the rest screen (Feature 5).
    static let posturePrompts = [
        "Roll your shoulders back",
        "Take three deep breaths",
        "Sit up straight",
        "Relax your jaw",
        "Unclench your hands",
        "Drop your shoulders away from your ears",
    ]

    private enum Keys {
        static let interval = "intervalMinutes"
        static let warning = "warningMinutes"
        static let rest = "restDuration"
        static let sound = "soundEnabled"
        static let launch = "launchAtLogin"
        // V2 keys (iris.-prefixed)
        static let ambient = "iris.ambientSoundEnabled"
        static let autoPauseCalls = "iris.autoPauseDuringCalls"
        static let waitForGap = "iris.waitForNaturalGap"
        static let postureNudges = "iris.postureNudgesEnabled"
        static let quietEnabled = "iris.quietHoursEnabled"
        static let quietStart = "iris.quietHoursStart"
        static let quietEnd = "iris.quietHoursEnd"
        static let scheduleBlocks = "iris.scheduleBlocks"
        static let challenge = "iris.challenge"
        static let promptIndex = "iris.currentPromptIndex"
        static let nudgeFrequency = "iris.nudgeFrequency"
        static let focusBlocker = "iris.focusBlockerEnabled"
        static let blockedItems = "iris.blockedItems"
        // V3 keys (12 new features)
        static let stretchCards = "iris.stretchCardsEnabled"
        static let waterReminders = "iris.waterRemindersEnabled"
        static let problemArea = "iris.problemArea"
        static let standUpMode = "iris.standUpModeEnabled"
        static let lateNightGuard = "iris.lateNightGuardEnabled"
        static let lateNightHour = "iris.lateNightHour"
        static let brightnessCheck = "iris.brightnessCheckEnabled"
        static let windDown = "iris.windDownEnabled"
        static let deskReset = "iris.deskResetEnabled"
        static let wristRelief = "iris.wristReliefEnabled"
        static let postMeetingReset = "iris.postMeetingResetEnabled"
        static let scrollFatigue = "iris.scrollFatigueEnabled"
        static let postureCamera = "iris.postureCameraEnabled"
    }

    private init() {
        defaults.register(defaults: [
            Keys.interval: 20,
            Keys.warning: 2,
            Keys.rest: 20,
            Keys.sound: true,
            Keys.launch: false,
            Keys.ambient: true,
            Keys.autoPauseCalls: true,
            Keys.postureNudges: true,
            Keys.nudgeFrequency: NudgeFrequency.regularly.rawValue,
            Keys.quietEnabled: false,
            // V3 defaults — all features OFF except lateNightHour
            Keys.stretchCards: false,
            Keys.waterReminders: false,
            Keys.standUpMode: false,
            Keys.lateNightGuard: false,
            Keys.lateNightHour: 22,
            Keys.brightnessCheck: false,
            Keys.windDown: false,
            Keys.deskReset: false,
            Keys.wristRelief: false,
            Keys.postMeetingReset: false,
            Keys.scrollFatigue: false,
            Keys.postureCamera: false,
        ])

        intervalMinutes = Self.clamp(defaults.integer(forKey: Keys.interval), 5...120)
        warningMinutes = Self.clamp(defaults.integer(forKey: Keys.warning), 1...5)
        restDuration = Self.clamp(defaults.integer(forKey: Keys.rest), 10...60)
        soundEnabled = defaults.bool(forKey: Keys.sound)
        launchAtLogin = defaults.bool(forKey: Keys.launch)

        ambientSoundEnabled = defaults.bool(forKey: Keys.ambient)
        autoPauseDuringCalls = defaults.bool(forKey: Keys.autoPauseCalls)
        waitForNaturalGap = defaults.object(forKey: Keys.waitForGap) as? Bool ?? true
        postureNudgesEnabled = defaults.bool(forKey: Keys.postureNudges)
        let rawFreq = defaults.string(forKey: Keys.nudgeFrequency) ?? NudgeFrequency.regularly.rawValue
        nudgeFrequency = NudgeFrequency(rawValue: rawFreq) ?? .regularly
        quietHoursEnabled = defaults.bool(forKey: Keys.quietEnabled)
        quietHoursStart = (defaults.object(forKey: Keys.quietStart) as? Date)
            ?? Self.time(hour: 21, minute: 0)
        quietHoursEnd = (defaults.object(forKey: Keys.quietEnd) as? Date)
            ?? Self.time(hour: 8, minute: 0)
        scheduleBlocks = Self.loadScheduleBlocks(from: defaults, key: Keys.scheduleBlocks)
        challenge = Self.loadChallenge(from: defaults, key: Keys.challenge)
        focusBlockerEnabled = defaults.bool(forKey: Keys.focusBlocker)
        blockedItems = Self.loadBlockedItems(from: defaults, key: Keys.blockedItems)

        // V3 settings
        stretchCardsEnabled = defaults.bool(forKey: Keys.stretchCards)
        waterRemindersEnabled = defaults.bool(forKey: Keys.waterReminders)
        let rawArea = defaults.string(forKey: Keys.problemArea) ?? ProblemArea.eyes.rawValue
        problemArea = ProblemArea(rawValue: rawArea) ?? .eyes
        standUpModeEnabled = defaults.bool(forKey: Keys.standUpMode)
        lateNightGuardEnabled = defaults.bool(forKey: Keys.lateNightGuard)
        lateNightHour = defaults.integer(forKey: Keys.lateNightHour)
        brightnessCheckEnabled = defaults.bool(forKey: Keys.brightnessCheck)
        windDownEnabled = defaults.bool(forKey: Keys.windDown)
        deskResetEnabled = defaults.bool(forKey: Keys.deskReset)
        wristReliefEnabled = defaults.bool(forKey: Keys.wristRelief)
        postMeetingResetEnabled = defaults.bool(forKey: Keys.postMeetingReset)
        scrollFatigueEnabled = defaults.bool(forKey: Keys.scrollFatigue)
        postureCameraEnabled = defaults.bool(forKey: Keys.postureCamera)

        syncLoginItemStateFromSystem()
        registerSleepWakeObservers()
    }

    // MARK: - Lifecycle

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
        updateSuspensionStates()
        guard !isSuspended else { return }

        switch timerState {
        case .counting, .warning:
            timeRemaining -= 1
            if timeRemaining <= 0 {
                // Do not black the screen out mid-sentence. Hold briefly, but
                // only up to maxDeferralSeconds, so a break cannot be dodged
                // forever by simply never stopping typing.
                if shouldDeferBreak {
                    deferredSeconds += 1
                    timeRemaining = 1
                    return
                }
                deferredSeconds = 0
                beginRest()
            } else if timerState == .counting && timeRemaining <= Double(warningMinutes * unitMultiplier) {
                timerState = .warning
            }

        case .resting:
            restTimeRemaining -= 1
            if restTimeRemaining <= 0 {
                endRest()
            }

        case .idle, .scheduledPause:
            break
        }
    }

    /// A detected call is currently auto-pausing Iris (i.e. auto-pause is on, a
    /// call is active, and the user hasn't chosen to keep running).
    var isCallPaused: Bool {
        autoPauseDuringCalls && isCallActive && !userResumedDuringCall
    }

    /// Whether this exact moment is a bad one to interrupt, and we have not
    /// already waited too long.
    var shouldDeferBreak: Bool {
        guard waitForNaturalGap else { return false }
        guard deferredSeconds < Self.maxDeferralSeconds else { return false }
        return FlowDetector.shared.isInFlow
    }

    /// Why a break is being held, if it is. Nil when nothing is being held.
    var deferralReason: String? {
        guard waitForNaturalGap, deferredSeconds > 0 else { return nil }
        return FlowDetector.shared.reason
    }

    /// True when the countdown must not advance for any reason.
    var isSuspended: Bool {
        isPaused
            || timerState == .scheduledPause
            || isInQuietHours
            || isCallPaused
    }

    // MARK: - Transitions

    private func beginCounting() {
        isPaused = false
        timeRemaining = Double(effectiveIntervalMinutes * unitMultiplier)
        timerState = .counting
    }

    private func beginRest() {
        activeRestDuration = restDuration
        restTimeRemaining = restDuration
        timerState = .resting
    }

    private func endRest() {
        StatsEngine.shared.recordBreak()
        beginCounting()
    }

    // MARK: - User actions

    func restNow() {
        guard timerState != .resting else { return }
        isPaused = false
        beginRest()
    }

    func togglePause() {
        isPaused.toggle()
    }

    // MARK: - Suspension evaluation (calls / quiet hours / schedule blocks)

    /// Called by the call detector on the main thread.
    func setCallActive(_ active: Bool) {
        guard isCallActive != active else { return }
        isCallActive = active
        if active {
            callActiveDate = Date()
            // Auto-pausing mid-warning should retract the pill.
            if isCallPaused, timerState == .warning { timerState = .counting }
        } else {
            // Call ended → check duration for post-meeting reset (Feature 10).
            if let start = callActiveDate, postMeetingResetEnabled {
                let duration = Date().timeIntervalSince(start)
                if duration >= 30 * 60 {
                    onLongCallEnded?()
                }
            }
            callActiveDate = nil
            userResumedDuringCall = false
        }
    }

    /// Fired when a call lasting ≥30 minutes ends and postMeetingResetEnabled is true.
    var onLongCallEnded: (() -> Void)?

    /// Clears the pending water nudge; call when the user acknowledges drinking.
    func acknowledgeWaterDrink() {
        waterNudgePending = false
    }

    /// User chose to keep Iris running for the rest of this call session.
    func resumeDuringCall() {
        guard isCallActive else { return }
        userResumedDuringCall = true
    }

    private func updateSuspensionStates() {
        // Never interfere with an in-progress rest.
        guard timerState != .resting else { return }

        let now = Date()

        // --- Late-night guard (Feature 5) ---
        let lateNight = lateNightGuardEnabled && Self.isLateNight(now, afterHour: lateNightHour)
        if lateNight != isInLateNight { isInLateNight = lateNight }

        // --- Schedule blocks drive the authoritative .scheduledPause state ---
        if let (block, end) = computeActiveScheduleBlock(at: now) {
            scheduledEndDate = end
            if activeScheduleBlock != block { activeScheduleBlock = block }
            if timerState != .scheduledPause { timerState = .scheduledPause }
        } else if timerState == .scheduledPause {
            activeScheduleBlock = nil
            scheduledEndDate = nil
            beginCounting()   // block ended → resume + reset (per spec)
        } else if activeScheduleBlock != nil {
            activeScheduleBlock = nil
            scheduledEndDate = nil
        }

        // --- Quiet hours (soft pause) ---
        let quiet = quietHoursEnabled && Self.isInQuietWindow(now, start: quietHoursStart, end: quietHoursEnd)
        if quiet != isInQuietHours { isInQuietHours = quiet }

        // A soft suspension arriving mid-warning should retract the pill.
        if timerState == .warning, isInQuietHours || isCallPaused {
            timerState = .counting
        }
    }

    private func computeActiveScheduleBlock(at now: Date) -> (ScheduleBlock, Date)? {
        var best: (ScheduleBlock, Date)?
        for block in scheduleBlocks where block.isEnabled {
            if let end = block.activeEnd(at: now) {
                if best == nil || end > best!.1 {
                    best = (block, end)
                }
            }
        }
        return best
    }

    // MARK: - Posture prompts (Feature 5)

    /// Return the current posture prompt and advance the stored index for next time.
    func consumePosturePrompt() -> String {
        let count = Self.posturePrompts.count
        let index = ((defaults.integer(forKey: Keys.promptIndex)) % count + count) % count
        let text = Self.posturePrompts[index]
        defaults.set((index + 1) % count, forKey: Keys.promptIndex)
        return text
    }

    // MARK: - Schedule block management

    func addScheduleBlock(_ block: ScheduleBlock) {
        scheduleBlocks.append(block)
    }

    func deleteScheduleBlocks(at offsets: IndexSet) {
        scheduleBlocks.remove(atOffsets: offsets)
    }

    // MARK: - Display helpers

    var popoverStatus: PopoverStatus {
        if let block = activeScheduleBlock, let end = scheduledEndDate {
            return .scheduled(label: block.label, endsAt: end)
        }
        if isInQuietHours { return .quietHours }
        if isCallActive { return isCallPaused ? .callPaused : .callRunning }
        if isPaused { return .userPaused }
        return .counting
    }

    var formattedTimeRemaining: String {
        let total = max(0, Int(timeRemaining))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var warningFormattedTime: String {
        let total = max(0, Int(timeRemaining))
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    var intervalElapsedFraction: Double {
        let total = Double(intervalMinutes * unitMultiplier)
        guard total > 0 else { return 0 }
        return min(1, max(0, (total - timeRemaining) / total))
    }

    var warningFraction: Double {
        let total = Double(warningMinutes * unitMultiplier)
        guard total > 0 else { return 0 }
        return min(1, max(0, timeRemaining / total))
    }

    var restFraction: Double {
        let total = Double(activeRestDuration)
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(restTimeRemaining) / total))
    }

    // MARK: - Sleep / wake

    private func registerSleepWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(handleWillSleep),
                           name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(handleDidWake),
                           name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func handleWillSleep() {
        pausedBeforeSleep = isPaused
        isPaused = true
    }

    @objc private func handleDidWake() {
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
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("Iris: launch-at-login update failed: \(error.localizedDescription)")
            syncLoginItemStateFromSystem()
        }
    }

    // MARK: - Persistence helpers

    private func saveScheduleBlocks() {
        if let data = try? JSONEncoder().encode(scheduleBlocks) {
            defaults.set(data, forKey: Keys.scheduleBlocks)
        }
    }

    private func saveChallenge() {
        if let data = try? JSONEncoder().encode(challenge) {
            defaults.set(data, forKey: Keys.challenge)
        }
    }

    private static func loadScheduleBlocks(from defaults: UserDefaults, key: String) -> [ScheduleBlock] {
        guard let data = defaults.data(forKey: key),
              let blocks = try? JSONDecoder().decode([ScheduleBlock].self, from: data) else { return [] }
        return blocks
    }

    private static func loadChallenge(from defaults: UserDefaults, key: String) -> Challenge {
        guard let data = defaults.data(forKey: key),
              let challenge = try? JSONDecoder().decode(Challenge.self, from: data) else { return .default }
        return challenge
    }

    private func saveBlockedItems() {
        if let data = try? JSONEncoder().encode(blockedItems) {
            defaults.set(data, forKey: Keys.blockedItems)
        }
    }

    private static func loadBlockedItems(from defaults: UserDefaults, key: String) -> [BlockedItem] {
        guard let data = defaults.data(forKey: key),
              let items = try? JSONDecoder().decode([BlockedItem].self, from: data) else { return [] }
        return items
    }

    // MARK: - Time utilities

    private static func time(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private static func minutesOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    static func isLateNight(_ now: Date, afterHour hour: Int, calendar: Calendar = .current) -> Bool {
        let h = calendar.component(.hour, from: now)
        // After the chosen hour, OR before 5am (crosses midnight).
        return h >= hour || h < 5
    }

    static func isInQuietWindow(_ now: Date, start: Date, end: Date, calendar: Calendar = .current) -> Bool {
        let cur = minutesOfDay(now, calendar: calendar)
        let s = minutesOfDay(start, calendar: calendar)
        let e = minutesOfDay(end, calendar: calendar)
        guard s != e else { return false }
        if s < e {
            return cur >= s && cur < e
        } else {
            return cur >= s || cur < e   // window crosses midnight
        }
    }

    private static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
