//
//  WarningPillView.swift
//  Iris
//
//  Content for the notch-integrated countdown pill. On a notch Mac the pill
//  grows straight down out of the notch (matte black, seamless top corners); on
//  a non-notch Mac it slides down from the top edge as a floating pill. The
//  controller owns the window/geometry; this view owns rendering + state.
//

import SwiftUI

/// State bridge between the controller and the SwiftUI content.
final class WarningPillModel: ObservableObject {
    @Published var expanded = false
    @Published var hasNotch = true
    @Published var hovering = false
    @Published var pressed = false
    @Published var flashing = false
    @Published var reduceMotion = false

    // Notch geometry (updated by the controller at show time).
    var notchWidth: CGFloat = 200
    var notchHeight: CGFloat = 32
}

/// Rounded rectangle with independent top and bottom corner radii, so the top
/// can stay at the notch radius (10) while the bottom opens up (22).
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

struct WarningPillView: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject var model: WarningPillModel

    @State private var showSubtitle = false
    @State private var pausedPulse = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            pill.offset(y: yOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Pill

    private var pill: some View {
        let shape = NotchPillShape(topRadius: topRadius, bottomRadius: bottomRadius)
        return shape
            .fill(fillColor)
            .frame(width: pillWidth, height: pillHeight)
            .overlay(bottomInnerShadow.clipShape(shape))
            .overlay(content.opacity(model.expanded ? 1 : 0))
            .compositingGroup()
            .shadow(color: model.hasNotch ? .clear : .black.opacity(0.25),
                    radius: model.hasNotch ? 0 : 16, x: 0, y: 4)
            .scaleEffect(model.pressed ? 0.97 : 1, anchor: .top)
            .animation(growAnimation, value: model.expanded)
            .animation(hoverAnimation, value: model.hovering)
            .animation(.easeInOut(duration: 0.1), value: model.flashing)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: model.pressed)
            .onHover { model.hovering = $0 }
            .onTapGesture { engine.togglePause() }
    }

    private var content: some View {
        VStack(spacing: 1) {
            // Top zone sits within the notch height — kept empty.
            Spacer().frame(height: model.hasNotch ? 22 : 8)

            if engine.isPaused {
                Text("PAUSED")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: 0xF5F5F5).opacity(pausedPulse ? 0.4 : 0.6))
                    .onAppear {
                        guard !model.reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                            pausedPulse = true
                        }
                    }
            } else {
                HStack(spacing: 8) {
                    if model.hovering {
                        Text("Pause")
                            .font(.system(size: 10, weight: .light))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .transition(.opacity)
                    }
                    Text(engine.formattedTimeRemaining)
                        .font(.system(size: 28, weight: .thin))
                        .monospacedDigit()
                        .tracking(0.5)
                        .contentTransition(.numericText())
                        .foregroundStyle(Color(hex: 0xF5F5F5).opacity(model.hovering ? 0.7 : 0.95))
                        .animation(model.reduceMotion ? .easeInOut(duration: 0.18) : .easeInOut(duration: 0.18),
                                   value: engine.formattedTimeRemaining)
                    if model.hovering {
                        Circle().fill(Color.white.opacity(0.6)).frame(width: 4, height: 4)
                            .transition(.opacity)
                    }
                }
                if showSubtitle && !model.hovering {
                    Text("until break")
                        .font(.system(size: 9, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: pillWidth, height: pillHeight)
        .onChange(of: model.expanded) { expanded in
            if expanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeIn(duration: 0.3)) { showSubtitle = true }
                }
            } else {
                showSubtitle = false
            }
        }
    }

    /// Extremely subtle inner shadow along the bottom edge for depth on light wallpapers.
    private var bottomInnerShadow: some View {
        LinearGradient(colors: [.clear, .clear, .black.opacity(0.4)],
                       startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
    }

    // MARK: - Geometry

    private var yOffset: CGFloat {
        guard !model.hasNotch else { return 0 }
        return model.expanded ? 12 : -56
    }

    private var pillWidth: CGFloat {
        if !model.hasNotch { return 280 + (model.hovering ? 20 : 0) }
        return model.expanded ? model.notchWidth + 80 + (model.hovering ? 20 : 0) : model.notchWidth
    }

    private var pillHeight: CGFloat {
        if !model.hasNotch { return 56 + (model.hovering ? 8 : 0) }
        return model.expanded ? 72 + (model.hovering ? 8 : 0) : model.notchHeight
    }

    private var topRadius: CGFloat {
        model.hasNotch ? 10 : 28
    }

    private var bottomRadius: CGFloat {
        if !model.hasNotch { return 28 }
        return model.expanded ? 22 : 10
    }

    private var fillColor: Color {
        if model.flashing { return Color(hex: 0x1A1A1A) }
        return model.hasNotch ? .black : Color(hex: 0x0A0A0A)
    }

    // MARK: - Animations

    private var growAnimation: Animation {
        model.reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.82)
    }

    private var hoverAnimation: Animation {
        model.reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.3, dampingFraction: 0.85)
    }
}
