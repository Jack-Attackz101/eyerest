//
//  BoxBreathingView.swift
//  Iris
//
//  Guided box breathing during a break: 4 seconds in, 4 hold, 4 out, 4 hold.
//
//  A square, not a circle. A dot travels the perimeter and passes through every
//  corner in turn, and the corner is the whole point of the design: the turn is
//  what tells you the phase changed, so the dot has to reach the corner exactly
//  as the word in the middle changes. That means a linear rate, never an easing
//  curve, so four seconds a side is honest.
//
//  The travelled part of the perimeter stays lit behind the dot, and resets at
//  the top of each lap.
//

import SwiftUI

// MARK: - Phases

enum BreathPhase: Int, CaseIterable {
    case inhale, holdIn, exhale, holdOut

    var label: String {
        switch self {
        case .inhale:  return "breathe in"
        case .holdIn:  return "hold"
        case .exhale:  return "breathe out"
        case .holdOut: return "hold"
        }
    }
}

enum BoxBreathing {
    /// One side, and so one phase.
    static let phaseSeconds: Double = 4
    /// A full lap, which is one whole breath.
    static let cycleSeconds: Double = phaseSeconds * 4
    /// The square, sized to read on a 13 inch screen without dominating it.
    static let side: CGFloat = 240

    /// Whether a rest is long enough for at least one complete lap. A partial
    /// lap is worse than no lap, so short breaks show the posture prompt.
    static func fits(restDuration: Int) -> Bool {
        Double(restDuration) >= cycleSeconds
    }

    /// How far round the current lap, 0 to 1. Linear, so four seconds a side is
    /// four seconds a side.
    static func lapProgress(elapsed: Double) -> Double {
        let t = max(0, elapsed).truncatingRemainder(dividingBy: cycleSeconds)
        return t / cycleSeconds
    }

    /// The phase the dot is travelling through. Each side is one phase, so the
    /// word changes exactly as the dot turns the corner.
    static func phase(elapsed: Double) -> BreathPhase {
        let index = Int(lapProgress(elapsed: elapsed) * 4) % 4
        return BreathPhase(rawValue: index) ?? .inhale
    }
}

// MARK: - View

struct BoxBreathingView: View {
    /// Seconds elapsed since the breathing started. Driven by the break clock so
    /// the animation cannot drift away from the countdown.
    let elapsed: Double
    let theme: BreakTheme
    let reduceMotion: Bool

    private var lapProgress: Double { BoxBreathing.lapProgress(elapsed: elapsed) }
    private var phase: BreathPhase { BoxBreathing.phase(elapsed: elapsed) }

    var body: some View {
        ZStack {
            // The full square, unlit.
            BoxPerimeter()
                .stroke(theme.ringTrack, style: StrokeStyle(lineWidth: 3, lineCap: .round))

            if !reduceMotion {
                // The travelled part, lit behind the dot.
                BoxPerimeter()
                    .trim(from: 0, to: lapProgress)
                    .stroke(theme.ringFill.opacity(0.85),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))

                Circle()
                    .fill(theme.ringFill)
                    .frame(width: 12, height: 12)
                    .position(BoxPerimeter.point(at: lapProgress,
                                                 in: CGRect(x: 0, y: 0,
                                                            width: BoxBreathing.side,
                                                            height: BoxBreathing.side)))
            }

            Text(phase.label)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(theme.secondaryText)
                .animation(nil, value: phase)   // the corner is the cue, not a fade
        }
        .frame(width: BoxBreathing.side, height: BoxBreathing.side)
    }
}

// MARK: - Geometry

/// The square's perimeter, starting at the bottom left and running
/// anticlockwise on screen: along the bottom, up the right, back along the top,
/// down the left. That order is what makes each side a phase:
/// bottom is breathe in, right is hold, top is breathe out, left is hold.
struct BoxPerimeter: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))   // bottom, left to right
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))   // right, going up
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))   // top, right to left
        p.closeSubpath()                                      // left, coming down
        return p
    }

    /// Where the dot is at a given fraction of the lap, on the same path.
    static func point(at progress: Double, in rect: CGRect) -> CGPoint {
        let t = min(max(progress, 0), 1)
        let side = t * 4
        let leg = min(Int(side), 3)          // 4 legs, clamped at the wrap
        let along = side - Double(leg)       // 0 to 1 along this leg
        switch leg {
        case 0:  return CGPoint(x: rect.minX + rect.width * along, y: rect.maxY)
        case 1:  return CGPoint(x: rect.maxX, y: rect.maxY - rect.height * along)
        case 2:  return CGPoint(x: rect.maxX - rect.width * along, y: rect.minY)
        default: return CGPoint(x: rect.minX, y: rect.minY + rect.height * along)
        }
    }
}
