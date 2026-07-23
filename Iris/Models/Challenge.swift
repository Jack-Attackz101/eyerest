//
//  Challenge.swift
//  Iris
//
//  The morning physical challenge (Feature 7). Each exercise carries its own
//  reps label and a required hold duration — the Done button can't appear until
//  the hold completes.
//

import Foundation

// MARK: - Challenge

struct Challenge: Codable, Equatable {
    /// Raw value of Exercise, or Challenge.surpriseMeID for a random pick each morning.
    var exerciseID: String
    var isEnabled: Bool
    var wakeTime: Date   // Only the time-of-day components are used.
    var bedtime: Date    // Only the time-of-day components are used.

    static let surpriseMeID = "surpriseMe"

    var isSurpriseMe: Bool { exerciseID == Self.surpriseMeID }

    /// Resolves to a concrete exercise; random for "Surprise me".
    func resolvedExercise() -> Exercise {
        if isSurpriseMe { return Exercise.allCases.randomElement() ?? .jumpingJacks }
        return Exercise(rawValue: exerciseID) ?? .jumpingJacks
    }

    static var `default`: Challenge {
        Challenge(
            exerciseID: Exercise.jumpingJacks.rawValue,
            isEnabled: false,
            wakeTime: tod(hour: 6, minute: 30),
            bedtime: tod(hour: 22, minute: 30)
        )
    }

    private static func tod(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - Exercise

enum Exercise: String, CaseIterable, Identifiable {
    case jumpingJacks    = "Jumping Jacks"
    case squats          = "Squats"
    case deskPushUps     = "Desk Push-ups"
    case highKnees       = "High Knees"
    case wallSit         = "Wall Sit"
    case calfRaises      = "Calf Raises"
    case standingStretch = "Standing Stretch"

    var id: String { rawValue }

    /// Hold duration in seconds — the minimum time before Done appears.
    var holdDuration: Int {
        switch self {
        case .jumpingJacks:    return 20
        case .squats:          return 30
        case .deskPushUps:     return 25
        case .highKnees:       return 20
        case .wallSit:         return 30
        case .calfRaises:      return 25
        case .standingStretch: return 20
        }
    }

    /// Short reps text shown on the challenge screen below the name.
    var repsDisplay: String {
        switch self {
        case .jumpingJacks:    return "× 10"
        case .squats:          return "× 10"
        case .deskPushUps:     return "× 10"
        case .highKnees:       return "× 20"
        case .wallSit:         return "hold"
        case .calfRaises:      return "× 15"
        case .standingStretch: return "hold"
        }
    }

    /// Human-readable reps label for the settings picker.
    var repsDescription: String {
        switch self {
        case .jumpingJacks:    return "10 reps"
        case .squats:          return "10 reps"
        case .deskPushUps:     return "10 reps"
        case .highKnees:       return "20 reps"
        case .wallSit:         return "hold"
        case .calfRaises:      return "15 reps"
        case .standingStretch: return "hold"
        }
    }

    /// "Jumping Jacks · 10 reps · 20s" label for the exercise picker.
    var pickerLabel: String { "\(rawValue) · \(repsDescription) · \(holdDuration)s" }

    var symbolName: String {
        switch self {
        case .jumpingJacks:    return "figure.jumprope"
        case .squats:          return "figure.squat"
        case .deskPushUps:     return "figure.strengthtraining.traditional"
        case .highKnees:       return "figure.run"
        case .wallSit:         return "figure.stand"
        case .calfRaises:      return "figure.walk"
        case .standingStretch: return "figure.cooldown"
        }
    }

    static func from(_ raw: String) -> Exercise {
        Exercise(rawValue: raw) ?? .jumpingJacks
    }
}
