//
//  Challenge.swift
//  Iris
//
//  A physical challenge the user must complete after unlocking (Feature 7).
//

import Foundation

struct Challenge: Codable, Equatable {
    var exercise: String
    var reps: Int
    var isEnabled: Bool
    var triggerMode: TriggerMode
    var morningStartHour: Int

    enum TriggerMode: String, Codable, CaseIterable, Identifiable {
        case morningOnly
        case everyUnlock
        case both

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .morningOnly: return "Morning only"
            case .everyUnlock: return "Every unlock"
            case .both: return "Both"
            }
        }

        /// Whether this trigger involves the morning-time gate.
        var usesMorningTime: Bool { self != .everyUnlock }
    }

    static let `default` = Challenge(
        exercise: Exercise.pushUps.rawValue,
        reps: 10,
        isEnabled: false,
        triggerMode: .morningOnly,
        morningStartHour: 6
    )
}

/// The fixed set of exercises the user can choose from (no custom text).
enum Exercise: String, CaseIterable, Identifiable {
    case pushUps = "Push-ups"
    case sitUps = "Sit-ups"
    case squats = "Squats"
    case jumpingJacks = "Jumping Jacks"
    case burpees = "Burpees"
    case wallSit = "Wall Sit"
    case deepBreaths = "Deep Breaths"

    var id: String { rawValue }

    /// Closest available SF Symbol for each exercise.
    var symbolName: String {
        switch self {
        case .pushUps: return "figure.strengthtraining.traditional"
        case .sitUps: return "figure.core.training"
        case .squats: return "figure.squat"
        case .jumpingJacks: return "figure.jumprope"
        case .burpees: return "figure.highintensity.intervaltraining"
        case .wallSit: return "figure.stand"
        case .deepBreaths: return "wind"
        }
    }

    /// The unit for the rep count. Wall Sit / Deep Breaths aren't literal "reps".
    var repUnit: String {
        switch self {
        case .wallSit: return "seconds"
        case .deepBreaths: return "breaths"
        default: return "reps"
        }
    }

    /// Resolve an exercise from a stored raw string, defaulting to push-ups.
    static func from(_ raw: String) -> Exercise {
        Exercise(rawValue: raw) ?? .pushUps
    }
}
