//
//  WarningPillView.swift
//  Iris
//
//  Compact horizontal pill that wraps the notch, one row:
//  [pause button | MM:SS countdown | depleting ring].
//
//  The pill is flush with the physical top of the display and square across the
//  top on every Mac, notch or not. It used to float 8pt down and fully rounded
//  when no notch was detected, which is what produced the grey strip above it
//  and the rounded top corners in the screenshot from Jack's machine: his screen
//  reports safeAreaInsets.top == 0, so the fallback was rendering. Whether the
//  hardware has a notch now decides the pill's width, and nothing else.
//

import SwiftUI

// MARK: - Model

final class WarningPillModel: ObservableObject {
    @Published var expanded = false
    @Published var hasNotch = true
    @Published var hovering = false   // retained for controller compat, unused in view
    @Published var pressed = false    // retained for controller compat, unused in view
    @Published var flashing = false
    @Published var reduceMotion = false

    var notchWidth: CGFloat = 200
    var notchHeight: CGFloat = 32
}

// MARK: - Shape

/// Custom shape: independent top and bottom corner radii.
/// For the notch pill: topRadius = 0 (flush with screen), bottomRadius = 20.
struct NotchPillShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let tr = max(0, min(topRadius, rect.width / 2))
        let br = max(0, min(bottomRadius, rect.width / 2))
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + tr))
        p.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - br),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Metrics

/// Shared with WarningPillController, which sizes the panel from the same
/// numbers. When they disagree the pill floats inside a larger transparent
/// panel, which is one of the ways this went wrong before.
enum PillMetrics {
    static let pillH: CGFloat = 44       // total pill height
    static let sideExt: CGFloat = 55     // extension on each side of notch
    static let botR: CGFloat = 20        // bottom corner radius, both cases
    static let fallW: CGFloat = 240      // fixed width when there is no notch
    static let countdownDrop: CGFloat = 4 // pushes text below camera zone (notch only)

    // There is deliberately no gap constant and no top-corner radius constant.
    // The pill hangs from the physical top edge on every Mac, so both would be
    // zero, and a knob that must always be zero is a knob someone eventually
    // sets back to 8.
}

private typealias M = PillMetrics

// MARK: - View

struct WarningPillView: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject var model: WarningPillModel

    @State private var contentVisible = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            pill.offset(y: yOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: model.expanded) { expanded in
            if expanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.easeIn(duration: 0.22)) { contentVisible = true }
                }
            } else {
                withAnimation(.easeOut(duration: 0.08)) { contentVisible = false }
            }
        }
    }

    // MARK: - Pill shell

    private var fillColor: Color {
        model.flashing ? Color(hex: 0x1A1A1A) : Color.black
    }

    private var pill: some View {
        pillBackground
            .frame(width: pillWidth, height: pillHeight)
            .overlay(pillContent.opacity(contentVisible ? 1 : 0))
            .animation(growAnim, value: model.expanded)
            .animation(.easeInOut(duration: 0.1), value: model.flashing)
    }

    /// Square across the top, rounded below, on every Mac. A shadow would show
    /// as a smudge above the pill against the screen edge, so there is none.
    private var pillBackground: some View {
        NotchPillShape(topRadius: 0, bottomRadius: M.botR).fill(fillColor)
    }

    // MARK: - Content row

    private var pillContent: some View {
        HStack(spacing: 0) {
            // Left 55pt: pause / resume
            pauseButton
                .frame(width: M.sideExt)

            // Center (notch width): countdown, nudged below camera
            countdownText
                .frame(maxWidth: .infinity)
                .offset(y: model.hasNotch ? M.countdownDrop : 0)

            // Right 55pt: depleting ring
            progressRing
                .frame(width: M.sideExt)
        }
        .frame(width: pillWidth, height: M.pillH)
    }

    // MARK: - Elements

    private var pauseButton: some View {
        Button { engine.togglePause() } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: engine.isPaused ? "play.fill" : "hand.raised.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var countdownText: some View {
        Text(engine.formattedTimeRemaining)
            .font(.system(size: 22, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .animation(.easeInOut(duration: 0.18), value: engine.formattedTimeRemaining)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: engine.warningFraction)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: engine.warningFraction)
        }
        .frame(width: 26, height: 26)
    }

    // MARK: - Geometry

    private var pillWidth: CGFloat {
        model.hasNotch
            ? (model.expanded ? model.notchWidth + M.sideExt * 2 : model.notchWidth)
            : M.fallW
    }

    private var pillHeight: CGFloat {
        model.hasNotch
            ? (model.expanded ? M.pillH : model.notchHeight)
            : M.pillH
    }

    private var yOffset: CGFloat {
        guard !model.hasNotch else { return 0 }
        // Flush when shown, fully above the top edge when hidden.
        return model.expanded ? 0 : -M.pillH
    }

    // MARK: - Animations

    private var growAnim: Animation {
        model.reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.42, dampingFraction: 0.82)
    }
}
