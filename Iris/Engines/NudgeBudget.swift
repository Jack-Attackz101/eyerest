//
//  NudgeBudget.swift
//  Iris
//
//  One gate in front of every non-break nudge.
//
//  Why this exists: Iris grew eight independent sources of interruption (eye
//  breaks, posture nudges, camera posture alerts, water, stand up, wrist relief,
//  scroll fatigue, desk reset). Each one was reasonable on its own and each one
//  fired without knowing about the others, so on a busy afternoon they stack.
//  Reminder overload is the most cited complaint against the biggest app in this
//  category, and Iris ships more nudge sources than it does, so the count is not
//  the thing to fix. The pacing is.
//
//  Every non-break nudge now asks here first:
//
//      NudgeBudget.shared.request(.water) { text in show(text) }
//
//  The closure is a presenter, not a side-effect hook. It runs only if the
//  request is granted, and exactly one closure runs per nudge shown: when two
//  requests land close together they are merged into a single combined nudge and
//  the higher-priority source presents it for both. So do not put bookkeeping
//  the engine depends on inside the closure.
//
//  What it enforces, in order of how often it bites:
//
//    1. A minimum gap between any two nudges of any kind.
//    2. A hard cap per rolling hour.
//    3. Nothing in the last minute before a scheduled eye break, and nothing
//       during a break, a challenge, the wind down or the desk reset. Break and
//       suspension state is read from TimerEngine rather than tracked again
//       here; the three overlays live in controllers, so the budget asks
//       AppDelegate about them through `isOverlayOnScreen`.
//    4. Nothing while FlowDetector reports flow.
//    5. When several want the same window, priority decides who speaks. A loser
//       is dropped, never queued, because a "drink some water" that arrives
//       twenty minutes late is worse than no nudge at all.
//    6. Two requests inside the coalescing window become one nudge with two
//       actions, never two pills.
//
//  This is only a gate. No engine's detection logic lives here, and the budget
//  never invents a nudge of its own.
//
//  Main thread only. Every caller is already there (all four engine timers run
//  on the main run loop and PostureCameraEngine is @MainActor), and a request
//  arriving from anywhere else is hopped rather than dropped.
//

import Foundation
import Combine

final class NudgeBudget: ObservableObject {

    /// Shared gate. There is deliberately only one, so the budget is global
    /// rather than per-engine.
    static let shared = NudgeBudget()

    // MARK: - Tuning
    //
    // Every knob is here, one constant each. These are the numbers to move when
    // real use says the budget is too tight or too loose.

    /// Minimum gap between any two nudges, whatever their source.
    static let minimumGapMinutes: Double = 8

    /// Hard cap on nudges shown in any rolling hour.
    static let nudgesPerHourCap: Int = 4

    /// Requests landing within this many seconds of each other are shown as one
    /// combined nudge, which means a granted nudge is held for up to this long
    /// before it appears. That delay is the price of never showing two pills.
    static let coalesceWindowSeconds: Double = 90

    /// No nudge this close to a scheduled eye break.
    static let breakLeadInSeconds: Double = 60

    /// Never more than this many actions in one combined nudge. The joiner below
    /// assumes two.
    static let combinedActionCap: Int = 2

    // With DebugConfig.fastCycle on, the whole app treats a minute as a second.
    // The budget scales with it, otherwise nothing would ever be granted during
    // a fast-cycle test run.
    private static var scale: Double { DebugConfig.fastCycle ? 1.0 / 60.0 : 1.0 }

    static var minimumGap: TimeInterval { minimumGapMinutes * 60 * scale }
    static var hourWindow: TimeInterval { 60 * 60 * scale }
    static var coalesceWindow: TimeInterval { coalesceWindowSeconds * scale }
    static var breakLeadIn: TimeInterval { breakLeadInSeconds * scale }

    // MARK: - Sources

    /// Every non-break nudge in the app.
    ///
    /// Declaration order is priority order, highest first. The first five are
    /// the published order: posture camera alert beats wrist relief beats scroll
    /// fatigue beats water beats stand up. The last three were already firing
    /// through the same menu-bar pill, so they go through the gate too rather
    /// than being left as a hole in it, and they sit at the bottom because each
    /// one is a note about the ambient situation rather than an action the body
    /// needs now.
    enum Source: String, CaseIterable, Identifiable {
        case postureCamera
        case wristRelief
        case scrollFatigue
        case water
        case standUp
        case posture
        case postMeetingReset
        case lateNightWrapUp
        case brightness

        var id: String { rawValue }

        /// Lower wins. Declaration order is the ranking.
        var priority: Int {
            Source.allCases.firstIndex(of: self) ?? Source.allCases.count
        }

        /// Shown when this is the only nudge in the window.
        var text: String {
            switch self {
            case .postureCamera:    return "sit up straight"
            case .wristRelief:      return "shake out your wrists"
            case .scrollFatigue:    return "rest your wrists"
            case .water:            return "drink some water"
            case .standUp:          return "time to stand up"
            case .posture:          return "sit up straight"
            case .postMeetingReset: return "look away for 20 seconds"
            case .lateNightWrapUp:  return "time to wrap up"
            case .brightness:       return "lower your brightness"
            }
        }

        /// Used when two nudges are merged, so the combined line reads as one
        /// instruction: "stand up and shake out your wrists". Deliberately
        /// terser than `text`, because two of these plus a joiner have to fit in
        /// the menu bar (44 characters, see AppDelegate).
        var actionPhrase: String {
            switch self {
            case .postureCamera:    return "sit up straight"
            case .wristRelief:      return "shake out your wrists"
            case .scrollFatigue:    return "rest your wrists"
            case .water:            return "drink some water"
            case .standUp:          return "stand up"
            case .posture:          return "sit up straight"
            case .postMeetingReset: return "look away"
            case .lateNightWrapUp:  return "wrap up"
            case .brightness:       return "dim your screen"
            }
        }

        /// Short name for the debug counter.
        var label: String {
            switch self {
            case .postureCamera:    return "Posture camera"
            case .wristRelief:      return "Wrist relief"
            case .scrollFatigue:    return "Scroll fatigue"
            case .water:            return "Water"
            case .standUp:          return "Stand up"
            case .posture:          return "Posture nudges"
            case .postMeetingReset: return "Post-meeting"
            case .lateNightWrapUp:  return "Late night"
            case .brightness:       return "Brightness"
            }
        }
    }

    /// Why a request was turned down. Debug-facing only.
    enum DenialReason: String {
        case tooSoon           // inside the minimum gap
        case hourlyCap         // already at the cap for this hour
        case breakImminent     // inside the lead-in before a scheduled break
        case breakInProgress
        case timerSuspended    // paused, quiet hours, a call, a schedule block
        case timerNotRunning
        case overlayOnScreen   // challenge, wind down or desk reset
        case inFlow
        case crowdedOut        // lost the priority contest in its own window
        case alreadyPending    // same source asked twice in one window
    }

    // MARK: - Collaborators

    /// Set by AppDelegate. True while a challenge, the wind down or the desk
    /// reset owns the screen. Those are owned by controllers rather than
    /// TimerEngine, so the budget asks instead of reaching across the app.
    var isOverlayOnScreen: (() -> Bool)?

    // MARK: - State

    private let engine = TimerEngine.shared

    /// Presenters collected in the open coalescing window.
    private var pending: [Source: (String) -> Void] = [:]
    /// What to call when a source that cares is refused.
    private var refusalHandlers: [Source: () -> Void] = [:]
    /// Caller-supplied lines for the solo case, by source.
    private var customTexts: [Source: String] = [:]
    private var flushTimer: Timer?

    /// When the last nudge was actually shown, and the ones inside the hour.
    private var lastShown: Date?
    private var shownDates: [Date] = []

    private init() {}

    // MARK: - The one call

    /// Ask to interrupt, and be told when the answer is no.
    ///
    /// Most callers are event-driven: something happened, and if this is a bad
    /// moment the nudge is simply dropped. Periodic sources are different. A
    /// posture nudge that gets refused has to go back in the queue, or refusing
    /// one silently ends the whole series, so those pass `onRefused` and
    /// reschedule themselves. The refusal may arrive later than the call, since
    /// a request can be turned down when its coalescing window closes.
    func request(_ source: Source,
                 text: String? = nil,
                 present: @escaping (String) -> Void,
                 onRefused: @escaping () -> Void) {
        refusalHandlers[source] = onRefused
        request(source, text: text, present: present)
    }

    /// Ask to interrupt. `present` runs only if the request is granted, and is
    /// handed the exact text to show, which may be a combined line covering
    /// another source as well.
    /// `text` replaces the source's own line when this nudge ends up on screen
    /// alone. Posture nudges rotate through eight lines, and the budget should
    /// not have to know them. When two nudges merge, the terse `actionPhrase` is
    /// used regardless, because two full lines do not fit the menu bar.
    func request(_ source: Source, text: String? = nil, present: @escaping (String) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.request(source, text: text, present: present)
            }
            return
        }

        let now = Date()
        if let reason = denialReason(at: now) {
            deny(source, reason)
            return
        }
        guard pending[source] == nil else {
            deny(source, .alreadyPending)
            return
        }

        pending[source] = present
        customTexts[source] = text
        if flushTimer == nil { startFlushTimer() }
    }

    // MARK: - Gate

    /// The first rule this moment breaks, if any.
    private func denialReason(at now: Date) -> DenialReason? {
        switch engine.timerState {
        case .resting: return .breakInProgress
        case .idle:    return .timerNotRunning
        default:       break
        }
        if engine.isSuspended { return .timerSuspended }
        if isOverlayOnScreen?() == true { return .overlayOnScreen }
        if engine.timeRemaining <= Self.breakLeadIn { return .breakImminent }
        if FlowDetector.shared.isInFlow { return .inFlow }
        if let last = lastShown, now.timeIntervalSince(last) < Self.minimumGap { return .tooSoon }
        if countShown(since: now.addingTimeInterval(-Self.hourWindow)) >= Self.nudgesPerHourCap {
            return .hourlyCap
        }
        return nil
    }

    // MARK: - Coalescing

    private func startFlushTimer() {
        let timer = Timer(timeInterval: Self.coalesceWindow, repeats: false) { [weak self] _ in
            self?.flush()
        }
        RunLoop.main.add(timer, forMode: .common)
        flushTimer = timer
    }

    /// The window closed. Re-check the gate, because up to 90 seconds have
    /// passed and the user may have started typing or a break may be due, then
    /// show at most one nudge for the whole group.
    private func flush() {
        flushTimer?.invalidate()
        flushTimer = nil

        let group = pending
        let texts = customTexts
        pending = [:]
        customTexts = [:]
        guard !group.isEmpty else { return }

        let now = Date()
        if let reason = denialReason(at: now) {
            for source in group.keys { deny(source, reason) }
            return
        }

        let ranked = group.keys.sorted { $0.priority < $1.priority }
        let winners = Array(ranked.prefix(Self.combinedActionCap))
        for loser in ranked.dropFirst(Self.combinedActionCap) { deny(loser, .crowdedOut) }
        guard let presenter = winners.first else { return }

        lastShown = now
        shownDates.append(now)
        shownDates.removeAll { now.timeIntervalSince($0) >= Self.hourWindow }
        for winner in winners { grant(winner) }

        group[presenter]?(Self.combinedText(for: winners, custom: texts))
    }

    /// One nudge, at most two actions.
    static func combinedText(for sources: [Source], custom: [Source: String] = [:]) -> String {
        guard let first = sources.first else { return "" }
        guard sources.count > 1 else { return custom[first] ?? first.text }
        return sources.map(\.actionPhrase).joined(separator: " and ")
    }

    // MARK: - Introspection

    /// Nudges shown in the last hour. Read by the debug counter.
    var shownInLastHour: Int {
        countShown(since: Date().addingTimeInterval(-Self.hourWindow))
    }

    /// Seconds until the minimum gap allows another nudge. Zero when open.
    var secondsUntilGapClears: Int {
        guard let last = lastShown else { return 0 }
        return max(0, Int((Self.minimumGap - Date().timeIntervalSince(last)).rounded(.up)))
    }

    private func countShown(since cutoff: Date) -> Int {
        shownDates.reduce(into: 0) { count, date in
            if date > cutoff { count += 1 }
        }
    }

    // MARK: - Counters (DEBUG)

#if DEBUG

    struct Tally {
        var granted: Int = 0
        var denied: Int = 0
        var lastDenial: DenialReason?
    }

    /// Granted and denied counts per source, so it is possible to see in real
    /// use whether the budget is too tight rather than guessing.
    @Published private(set) var tallies: [Source: Tally] = [:]

    func resetTallies() {
        tallies = [:]
    }

#endif

    private func grant(_ source: Source) {
        clearRefusal(source)
#if DEBUG
        var tally = tallies[source] ?? Tally()
        tally.granted += 1
        tallies[source] = tally
#endif
    }

    private func deny(_ source: Source, _ reason: DenialReason) {
        if let handler = refusalHandlers.removeValue(forKey: source) { handler() }
        record(denial: source, reason)
    }

    /// A granted source no longer needs its refusal handler.
    private func clearRefusal(_ source: Source) {
        refusalHandlers.removeValue(forKey: source)
    }

    private func record(denial source: Source, _ reason: DenialReason) {
#if DEBUG
        var tally = tallies[source] ?? Tally()
        tally.denied += 1
        tally.lastDenial = reason
        tallies[source] = tally
#endif
    }
}
