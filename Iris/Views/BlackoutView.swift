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
    /// Posture nudge (Feature 5). Shown a couple of seconds into the rest.
    @Published var promptText: String = ""
    @Published var showPrompt: Bool = false
}

struct BlackoutView: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject var model: BlackoutModel

    var body: some View {
        ZStack {
            Color.black

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
                        .font(.system(size: 15, weight: .light))
                        .italic()
                        .foregroundStyle(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                        .padding(.top, 12)
                        .opacity(model.showPrompt ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5), value: model.showPrompt)
                }
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
    }
}
