//
//  BlackoutView.swift
//  Iris
//
//  The full-screen rest overlay shown on every display. Pure black with a
//  refined eye glyph, a depleting countdown ring, the remaining seconds, a
//  posture nudge, and a barely-there wordmark. Opacity is driven by the
//  controller for the fade in/out.
//

import SwiftUI

/// Drives the shared fade for all blackout panels.
final class BlackoutModel: ObservableObject {
    @Published var visible = false
    @Published var fadeDuration: Double = 0.6
    /// Posture nudge. Shown a couple of seconds into the rest.
    @Published var promptText: String = ""
    @Published var showPrompt: Bool = false
    /// Stretch card (Feature 1). Shown for the first 15 seconds of rest.
    @Published var stretchCard: StretchCard? = nil
    @Published var showStretchCard: Bool = false
}

struct BlackoutView: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject var model: BlackoutModel

    var body: some View {
        ZStack {
            Color.black

            if model.showStretchCard, let card = model.stretchCard {
                stretchCardView(card)
                    .transition(.opacity)
            } else {
                countdownView
                    .transition(.opacity)
            }

            VStack {
                Spacer()
                Text("iris")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.white.opacity(0.15))
                    .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .opacity(model.visible ? 1 : 0)
        .animation(.easeInOut(duration: model.fadeDuration), value: model.visible)
        .animation(.easeInOut(duration: 0.6), value: model.showStretchCard)
    }

    private var countdownView: some View {
        VStack(spacing: 18) {
            ZStack {
                CountdownRing(progress: engine.restFraction, diameter: 150, lineWidth: 3)
                Image(systemName: "eye")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Text("\(max(0, engine.restTimeRemaining))")
                .font(.system(size: 64, weight: .thin, design: .monospaced))
                .foregroundStyle(.white)

            Text("seconds")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.white.opacity(0.4))

            if !model.promptText.isEmpty {
                Text(model.promptText)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                    .padding(.top, 12)
                    .opacity(model.showPrompt ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5), value: model.showPrompt)
            }
        }
    }

    private func stretchCardView(_ card: StretchCard) -> some View {
        VStack(spacing: 24) {
            Image(systemName: card.symbol)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white.opacity(0.85))

            Text(card.title)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)

            Text(card.instruction)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .lineSpacing(4)

            Text("15 seconds")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }
}
