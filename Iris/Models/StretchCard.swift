//
//  StretchCard.swift
//  Iris
//
//  Rotating guided stretch cards, shown alongside the countdown for the whole
//  rest rather than in place of it.
//

import Foundation

struct StretchCard {
    let symbol: String
    let title: String
    let instruction: String
    let area: ProblemArea
}

extension StretchCard {
    static let all: [StretchCard] = [
        .init(symbol: "eye.circle", title: "20-20-20 Rule",
              instruction: "Find something 20 feet away and focus on it for the next 20 seconds.",
              area: .eyes),
        .init(symbol: "eye.slash.circle", title: "Blink & Rest",
              instruction: "Blink slowly 20 times to rehydrate your eyes, then close them and breathe.",
              area: .eyes),
        .init(symbol: "figure.stand", title: "Ear-to-Shoulder",
              instruction: "Tilt your right ear toward your shoulder. Hold 8 seconds. Switch sides.",
              area: .neck),
        .init(symbol: "arrow.up.and.down.circle", title: "Chin Tuck",
              instruction: "Gently draw your chin straight back. Hold 5 seconds. Repeat 5 times.",
              area: .neck),
        .init(symbol: "arrow.clockwise.circle", title: "Seated Cat-Cow",
              instruction: "Arch your back and look up, then round it forward. Repeat 5 times slowly.",
              area: .back),
        .init(symbol: "person.crop.circle", title: "Seated Twist",
              instruction: "Twist gently to the right, hold 8 seconds. Then to the left.",
              area: .back),
        .init(symbol: "hands.and.sparkles", title: "Wrist Circles",
              instruction: "Roll both wrists slowly in full circles, 10 rotations each direction.",
              area: .wrists),
        .init(symbol: "hand.raised.circle", title: "Prayer Stretch",
              instruction: "Press palms together at chest height and gently push downward. Hold 10 seconds.",
              area: .wrists),
    ]

    /// Return the next card, biased so the user's problem area comes up twice as often.
    static func consume(for area: ProblemArea, using defaults: UserDefaults) -> StretchCard {
        let key = "iris.stretchCardIndex"
        // Build a biased order: area cards twice, others once
        let primary = all.filter { $0.area == area }
        let others = all.filter { $0.area != area }
        let biased = primary + primary + others
        let count = biased.count
        let raw = defaults.integer(forKey: key)
        let index = ((raw % count) + count) % count
        defaults.set((index + 1) % count, forKey: key)
        return biased[index]
    }
}
