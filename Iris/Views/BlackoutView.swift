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

            // The countdown owns the centre of the screen and keeps the size and
            // position it has always had. The stretch card is a second element
            // lower down, not a replacement, so nothing has to shrink to make
            // room for it.
            countdownView

            VStack {
                Spacer()
                if model.showStretchCard, let card = model.stretchCard {
                    stretchCardView(card)
                        .padding(.bottom, 22)
                }
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

            // The breathing square and the stretch card both carry their own
            // words, so the posture prompt stands down rather than competing.
            if !model.promptText.isEmpty && !model.showBreathing && !model.showStretchCard {
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

    /// A distinct card, in the same rounded and outlined treatment the rest of
    /// the app uses, with every colour taken from the theme so it holds up on
    /// all five. It appears at full opacity as soon as the rest starts: on a
    /// twenty second break there is no time for it to fade in politely.
    private func stretchCardView(_ card: StretchCard) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: card.symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(model.theme.primaryText.opacity(0.9))
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(model.theme.primaryText)
                Text(card.instruction)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(model.theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: 420, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(model.theme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(model.theme.ringTrack, lineWidth: 1)
        )
    }
}
