//
//  ScheduleBlock.swift
//  Iris
//
//  A recurring rule that disables Iris for a defined window (Feature 6).
//

import Foundation

struct ScheduleBlock: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var startHour: Int        // 0–23
    var startMinute: Int      // 0–59
    var durationMinutes: Int  // how long Iris stays off
    var recurrence: Recurrence
    var isEnabled: Bool

    enum Recurrence: String, Codable, CaseIterable, Identifiable {
        case daily
        case weekdaysOnly
        case weekendsOnly

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .daily: return "Every day"
            case .weekdaysOnly: return "Weekdays"
            case .weekendsOnly: return "Weekends"
            }
        }
    }

    init(id: UUID = UUID(),
         label: String,
         startHour: Int,
         startMinute: Int,
         durationMinutes: Int,
         recurrence: Recurrence,
         isEnabled: Bool) {
        self.id = id
        self.label = label
        self.startHour = startHour
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.recurrence = recurrence
        self.isEnabled = isEnabled
    }

    // MARK: - Window evaluation

    /// Whether `recurrence` fires on the given weekday (1 = Sunday ... 7 = Saturday,
    /// matching `Calendar.component(.weekday:)`).
    private func fires(onWeekday weekday: Int) -> Bool {
        let isWeekend = (weekday == 1 || weekday == 7)
        switch recurrence {
        case .daily: return true
        case .weekdaysOnly: return !isWeekend
        case .weekendsOnly: return isWeekend
        }
    }

    /// If this block is active at `now`, returns the window's end date; otherwise nil.
    /// Handles windows that cross midnight by also checking yesterday's occurrence.
    func activeEnd(at now: Date, calendar: Calendar = .current) -> Date? {
        for dayOffset in [0, -1] {
            guard let base = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let start = calendar.date(
                      bySettingHour: startHour, minute: startMinute, second: 0, of: base
                  ) else { continue }
            let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
            let weekday = calendar.component(.weekday, from: start)
            if fires(onWeekday: weekday), now >= start, now < end {
                return end
            }
        }
        return nil
    }
}
