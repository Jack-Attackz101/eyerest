//
//  BreakTheme.swift
//  Iris
//
//  The five looks the break overlay can take. Every colour the blackout draws
//  comes from here, so contrast holds on all of them and nothing has to guess.
//  The palette is the brand palette from the site, not new colours.
//

import SwiftUI

enum BreakTheme: String, CaseIterable, Identifiable, Codable {
    case paper
    case ink
    case forest
    case dusk
    case tide
    /// Not a look of its own: picks one of the five each time a break starts.
    case random

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paper:  return "Paper"
        case .ink:    return "Ink"
        case .forest: return "Forest"
        case .dusk:   return "Dusk"
        case .tide:   return "Tide"
        case .random: return "Random each break"
        }
    }

    /// The themes that are actually drawable, in display order.
    static var concrete: [BreakTheme] { [.paper, .ink, .forest, .dusk, .tide] }

    /// Resolve a selection to something drawable.
    func resolved() -> BreakTheme {
        self == .random ? (BreakTheme.concrete.randomElement() ?? .paper) : self
    }

    // MARK: - Colours

    /// Top of the background gradient.
    var backgroundTop: Color {
        switch self {
        case .paper:  return Color(hex: 0xF4EFE6)
        case .ink:    return Color(hex: 0x0D0D0D)
        case .forest: return Color(hex: 0x1E2E1A)
        case .dusk:   return Color(hex: 0xC84B2F)
        case .tide:   return Color(hex: 0x5B9AB8)
        case .random: return BreakTheme.paper.backgroundTop
        }
    }

    /// Bottom of the background gradient. Equal to the top where the theme is flat.
    var backgroundBottom: Color {
        switch self {
        case .paper:  return Color(hex: 0xEDE6DA)
        case .ink:    return Color(hex: 0x050505)
        case .forest: return Color(hex: 0x152110)
        case .dusk:   return Color(hex: 0x3B1B12)   // deep warm brown
        case .tide:   return Color(hex: 0x10243A)   // deep navy
        case .random: return BreakTheme.paper.backgroundBottom
        }
    }

    /// The gradient, as stops rather than two ends.
    ///
    /// Dusk and Tide start on a mid-tone brand colour, and white on terracotta
    /// is 2.4:1 while white on that blue is 1.7:1. Neither is readable. The
    /// brand colour is therefore a band across the top and the gradient reaches
    /// its deep end by a third of the way down, so everything the eye actually
    /// reads sits on the deep end at better than 5:1. The two named colours are
    /// both still on screen, which is what the theme is.
    var backgroundStops: [Gradient.Stop] {
        [Gradient.Stop(color: backgroundTop, location: 0),
         Gradient.Stop(color: backgroundBottom, location: 0.34),
         Gradient.Stop(color: backgroundBottom, location: 1)]
    }

    /// What sits behind the countdown, the prompt and the breathing square. This
    /// is the colour every contrast decision is made against.
    var contentBackground: Color { backgroundBottom }

    /// Forest has a soft glow behind the countdown. Nil everywhere else.
    var glow: Color? {
        self == .forest ? Color(hex: 0x3D6B2E) : nil
    }

    /// True when the background behind the content needs dark text.
    private var isLight: Bool { self == .paper }

    /// Countdown, glyph and anything else that has to be read at a glance.
    var primaryText: Color {
        isLight ? Color(hex: 0x1C1C1E) : .white
    }

    /// Posture prompt and stretch instructions.
    var secondaryText: Color {
        isLight ? Color(hex: 0x1C1C1E).opacity(0.75) : .white.opacity(0.9)
    }

    /// "seconds", and other labels that are meant to recede.
    var tertiaryText: Color {
        isLight ? Color(hex: 0x1C1C1E).opacity(0.45) : .white.opacity(0.45)
    }

    /// The wordmark in the corner, which should be barely there.
    var wordmarkText: Color {
        isLight ? Color(hex: 0x1C1C1E).opacity(0.18) : .white.opacity(0.15)
    }

    /// A raised surface on top of the background, for the stretch card. A tint
    /// of the text colour rather than a fixed grey, so it lifts off Paper and
    /// off Ink by the same amount and never turns into a light box on a dark
    /// theme.
    var cardSurface: Color {
        (isLight ? Color(hex: 0x1C1C1E) : Color.white).opacity(0.07)
    }

    /// Depleting ring and the box breathing square.
    var ringTrack: Color {
        isLight ? Color(hex: 0x1C1C1E).opacity(0.12) : .white.opacity(0.15)
    }

    var ringFill: Color { primaryText }
}
