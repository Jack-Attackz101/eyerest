//
//  WarningPillView.swift
//  Iris
//
//  Compact horizontal pill that wraps the notch — one row:
//  [pause button | MM:SS countdown | depleting ring].
//  On notch Macs the pill is flush with the physical screen top
//  (top corners squared off). On non-notch Macs it floats 8pt below
//  the menu bar, fully rounded.
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

private enum M {
    static let pillH: CGFloat = 44       // total pill height
    static let sideExt: CGFloat = 55     // extension on each side of notch
    static let botR: CGFloat = 20        // notch-pill bottom corner radius
    static let fallW: CGFloat = 240      // non-notch pill width
    static let fallR: CGFloat = 22       // non-notch corner radius
    static let fallGap: CGFloat = 8      // gap from screen top (non-notch)
    static let countdownDrop: CGFloat = 4 // pushes text below camera zone (notch only)
}

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
            .shadow(color: model.hasNotch ? .clear : .black.opacity(0.28),
                    radius: model.hasNotch ? 0 : 12, x: 0, y: 3)
            .animation(growAnim, value: model.expanded)
            .animation(.easeInOut(duration: 0.1), value: model.flashing)
    }

    @ViewBuilder
    private var pillBackground: some View {
        if model.hasNotch {
            NotchPillShape(topRadius: 0, bottomRadius: M.botR).fill(fillColor)
        } else {
            RoundedRectangle(cornerRadius: M.fallR, style: .continuous).fill(fillColor)
        }
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
        return model.expanded ? M.fallGap : -(M.pillH + M.fallGap * 2)
    }

    // MARK: - Animations

    private var growAnim: Animation {
        model.reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.42, dampingFraction: 0.82)
    }
}
