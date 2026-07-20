//
//  WarningPillView.swift
//  EyeRest
//
//  The Dynamic Island-style pill that drops from the top of the screen during
//  the warning window. Its vertical offset is driven by `model.presented`, which
//  springs it in from off-screen and back out.
//

import SwiftUI

/// Drives the pill's slide animation from the controller.
final class WarningPillModel: ObservableObject {
    @Published var presented = false
}

struct WarningPillView: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject var model: WarningPillModel

    /// Off-screen (above) resting position vs. the visible 12pt-from-top position.
    private let hiddenOffset: CGFloat = -70
    private let shownOffset: CGFloat = 12

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white)

            Text("Break in \(engine.warningFormattedTime)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)

            Spacer(minLength: 4)

            CountdownRing(progress: engine.warningFraction, diameter: 20, lineWidth: 2)
        }
        .padding(.horizontal, 16)
        .frame(width: 260, height: 44)
        .background(Color(hex: 0x0A0A0A), in: Capsule())
        .offset(y: model.presented ? shownOffset : hiddenOffset)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: model.presented)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
