//
//  StatsEngine.swift
//  Iris
//
//  Lightweight local stats: streaks and break counts (Feature 2). All persisted
//  keys are prefixed "iris.".
//

import Foundation

final class StatsEngine: ObservableObject {

    static let shared = StatsEngine()

    /// A day counts toward a streak once the user completes at least this many breaks.
    static let breaksForStreak = 6

    @Published private(set) var currentStreak: Int
    @Published private(set) var longestStreak: Int
    @Published private(set) var breaksToday: Int
    @Published private(set) var totalBreaksAllTime: Int
    @Published private(set) var challengeStreak: Int
    /// Resets on every app launch (not persisted).
    @Published private(set) var breaksThisSession: Int = 0

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let currentStreak = "iris.currentStreak"
        static let longestStreak = "iris.longestStreak"
        static let breaksToday = "iris.breaksToday"
        static let breaksTodayDate = "iris.breaksTodayDate"
        static let breaksYesterday = "iris.breaksYesterday"
        static let lastStreakCheckDate = "iris.lastStreakCheckDate"
        static let totalBreaks = "iris.totalBreaksAllTime"
        static let challengeStreak = "iris.challengeStreak"
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private init() {
        currentStreak = defaults.integer(forKey: Keys.currentStreak)
        longestStreak = defaults.integer(forKey: Keys.longestStreak)
        breaksToday = defaults.integer(forKey: Keys.breaksToday)
        totalBreaksAllTime = defaults.integer(forKey: Keys.totalBreaks)
        challengeStreak = defaults.integer(forKey: Keys.challengeStreak)

        refreshForToday()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshForToday),
            name: .NSCalendarDayChanged,
            object: nil
        )
    }

    // MARK: - Public API

    /// Record one completed break.
    func recordBreak() {
        refreshForToday()
        breaksToday += 1
        breaksThisSession += 1
        totalBreaksAllTime += 1
        defaults.set(breaksToday, forKey: Keys.breaksToday)
        defaults.set(totalBreaksAllTime, forKey: Keys.totalBreaks)
    }

    // MARK: - Challenge streak

    func recordChallengeComplete() {
        challengeStreak += 1
        defaults.set(challengeStreak, forKey: Keys.challengeStreak)
    }

    func recordChallengeSkipped() {
        challengeStreak = 0
        defaults.set(challengeStreak, forKey: Keys.challengeStreak)
    }

    // MARK: - Daily bookkeeping

    /// Roll the day over if needed and (re)evaluate the streak. Safe to call often.
    @objc func refreshForToday() {
        let now = Date()
        rollOverDayIfNeeded(now: now)
        evaluateStreakIfNeeded(now: now)
    }

    private func rollOverDayIfNeeded(now: Date) {
        let today = Self.dayFormatter.string(from: now)
        let storedDay = defaults.string(forKey: Keys.breaksTodayDate)

        guard storedDay != today else { return }

        // The stored counter belongs to a previous day. If that day was literally
        // yesterday, preserve its count for the streak check; otherwise yesterday
        // had no activity.
        let yesterday = Self.dayFormatter.string(
            from: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        )
        let yesterdayCount = (storedDay == yesterday) ? breaksToday : 0
        defaults.set(yesterdayCount, forKey: Keys.breaksYesterday)

        breaksToday = 0
        defaults.set(0, forKey: Keys.breaksToday)
        defaults.set(today, forKey: Keys.breaksTodayDate)
    }

    private func evaluateStreakIfNeeded(now: Date) {
        let today = Self.dayFormatter.string(from: now)
        guard defaults.string(forKey: Keys.lastStreakCheckDate) != today else { return }

        let yesterdayCount = defaults.integer(forKey: Keys.breaksYesterday)
        if yesterdayCount >= Self.breaksForStreak {
            currentStreak += 1
        } else {
            currentStreak = 0
        }
        longestStreak = max(longestStreak, currentStreak)

        defaults.set(currentStreak, forKey: Keys.currentStreak)
        defaults.set(longestStreak, forKey: Keys.longestStreak)
        defaults.set(today, forKey: Keys.lastStreakCheckDate)
    }
}
