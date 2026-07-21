//
//  WarningPillView.swift
//  Iris
//
//  The warning HUD. On notch Macs it grows down out of the notch like a Dynamic
//  Island; on non-notch Macs it slides down from the top edge as a floating pill.
//

import SwiftUI

/// Drives the pill's expand/collapse from the controller.
final class WarningPillModel: ObservableObject {
    @Published var expanded = false
    @Published var hasNotch = false

    // Notch-mode geometry.
    let notchCollapsedWidth: CGFloat = 185
    let notchCollapsedHeight: CGFloat = 32
    let notchExpandedWidth: CGFloat = 320
    let notchExpandedHeight: CGFloat = 56

    // Non-notch fallback geometry.
    let floatWidth: CGFloat = 300
    let floatHeight: CGFloat = 52
}

struct WarningPillView: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject var model: WarningPillModel

    @State private var eyeScale: CGFloat = 1.0

    private var expandSpring: Animation { .spring(response: 0.5, dampingFraction: 0.68) }
    private var collapseSpring: Animation { .spring(response: 0.4, dampingFraction: 0.75) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            pill
                .offset(y: yOffset)
                .animation(model.expanded ? expandSpring : collapseSpring, value: model.expanded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Geometry

    private var yOffset: CGFloat {
        guard !model.hasNotch else { return 0 }        // notch mode grows in place
        return model.expanded ? 12 : -60               // fallback slides from above
    }

    private var width: CGFloat {
        if model.hasNotch { return model.expanded ? model.notchExpandedWidth : model.notchCollapsedWidth }
        return model.floatWidth
    }

    private var height: CGFloat {
        if model.hasNotch { return model.expanded ? model.notchExpandedHeight : model.notchCollapsedHeight }
        return model.floatHeight
    }

    private var radius: CGFloat {
        if model.hasNotch { return model.expanded ? 28 : 10 }
        return 26
    }

    private var fill: Color {
        // In notch mode the collapsed pill is pure black so it blends with the notch.
        (model.hasNotch && !model.expanded) ? .black : Color(hex: 0x0A0A0A)
    }

    // MARK: - Pill

    private var pill: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(fill)
                .overlay(
                    // Subtle inner shadow along the bottom edge only.
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.35)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: radius))
                    .allowsHitTesting(false)
                )
                .frame(width: width, height: height)
                .animation(model.expanded ? expandSpring : collapseSpring, value: model.expanded)

            content
                .frame(width: width, height: height)
                .opacity(model.expanded ? 1 : 0)
                .animation(.easeInOut(duration: 0.15).delay(model.expanded ? 0.15 : 0), value: model.expanded)
        }
        .frame(width: width, height: height)
    }

    private var content: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.fill")
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .scaleEffect(eyeScale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        eyeScale = 1.08
                    }
                }

            VStack(alignment: .leading, spacing: 0) {
                Text("Break in")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
                Text(engine.warningFormattedTime)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 6)

            Circle()
                .trim(from: 0, to: max(0, min(1, 1 - engine.warningFraction)))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 22, height: 22)
        }
        .padding(.horizontal, 16)
    }
}
