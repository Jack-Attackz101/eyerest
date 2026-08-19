//
//  BlackoutView.swift
//  Iris
//
//  The full-screen rest overlay shown on every display: an eye glyph, a
//  depleting countdown ring, the remaining seconds, a posture nudge or the box
//  breathing square, and a barely-there wordmark. Opacity is driven by the
//  controller for the fade in/out.
//
//  Every colour comes from the selected BreakTheme rather than being written
//  here, so all five themes hold their contrast.
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
    /// Resolved once per break, so "random each break" cannot reshuffle mid-rest
    /// and so every display shows the same theme.
    @Published var theme: BreakTheme = .paper
    /// Seconds since this break's breathing began, ticked by the controller.
    @Published var breathElapsed: Double = 0
    @Published var showBreathing: Bool = false
    @Published var reduceMotion: Bool = false
}

struct BlackoutView: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject var model: BlackoutModel

    var body: some View {
        ZStack {
            background

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
                    .foregroundStyle(model.theme.wordmarkText)
                    .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .opacity(model.visible ? 1 : 0)
        .animation(.easeInOut(duration: model.fadeDuration), value: model.visible)
        .animation(.easeInOut(duration: 0.6), value: model.showStretchCard)
    }

    /// A two stop gradient and, on Forest, one radial glow. This runs full
    /// screen on every display, so it stays this cheap. Reduce Motion gets the
    /// same thing: it is static either way.
    private var background: some View {
        ZStack {
            LinearGradient(stops: model.theme.backgroundStops,
                           startPoint: .top, endPoint: .bottom)
            if let glow = model.theme.glow {
                RadialGradient(colors: [glow.opacity(0.35), .clear],
                               center: .center, startRadius: 0, endRadius: 520)
            }
        }
    }

    private var countdownView: some View {
        VStack(spacing: 18) {
            if model.showBreathing {
                BoxBreathingView(elapsed: model.breathElapsed,
                                 theme: model.theme,
                                 reduceMotion: model.reduceMotion)
            } else {
                ZStack {
                    CountdownRing(progress: engine.restFraction, diameter: 150, lineWidth: 3)
                        .foregroundStyle(model.theme.ringFill)
                    Image(systemName: "eye")
                        .font(.system(size: 56))
                        .foregroundStyle(model.theme.primaryText.opacity(0.9))
                }
            }

            Text("\(max(0, engine.restTimeRemaining))")
                .font(.system(size: 64, weight: .thin, design: .monospaced))
                .foregroundStyle(model.theme.primaryText)

            Text("seconds")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(model.theme.tertiaryText)

            // The breathing square carries its own words, so the posture prompt
            // stands down while it is up rather than competing with it.
            if !model.promptText.isEmpty && !model.showBreathing {
                Text(model.promptText)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(model.theme.secondaryText)
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
                .foregroundStyle(model.theme.primaryText.opacity(0.85))

            Text(card.title)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(model.theme.primaryText)

            Text(card.instruction)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(model.theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .lineSpacing(4)

            Text("15 seconds")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(model.theme.tertiaryText)
                .padding(.top, 8)
        }
        .padding(.horizontal, 40)
    }
}
