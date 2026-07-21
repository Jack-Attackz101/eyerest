//
//  BlackoutView.swift
//  Iris
//
//  The full-screen rest overlay shown on every display. Pure black with the eye
//  glyph, a depleting countdown ring and the remaining seconds. Opacity is
//  driven by the controller for the fade in/out.
//

import SwiftUI

/// Drives the shared fade for all blackout panels.
final class BlackoutModel: ObservableObject {
    @Published var visible = false
    @Published var fadeDuration: Double = 0.6
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
                    Image(systemName: "eye.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                }

                Text("\(max(0, engine.restTimeRemaining))")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(.white)

                Text("seconds")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .opacity(model.visible ? 1 : 0)
        .animation(.easeInOut(duration: model.fadeDuration), value: model.visible)
    }
}
