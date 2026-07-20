//
//  MainView.swift
//  EyeRest
//
//  Default popover face: header, countdown ring, and the Pause/Rest Now buttons.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject private var engine: TimerEngine
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 18) {
            header
            ringSection
            actionButtons
        }
        .padding(20)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("EyeRest")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

            HStack {
                Image(systemName: "eye.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Countdown ring

    private var ringSection: some View {
        VStack(spacing: 8) {
            ZStack {
                CountdownRing(progress: engine.intervalElapsedFraction, diameter: 130, lineWidth: 3)
                Text(engine.formattedTimeRemaining)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            Text("until your next break")
                .font(.system(size: 12))
                .foregroundStyle(.gray)
        }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(engine.isPaused ? "Resume" : "Pause") {
                engine.togglePause()
            }
            .buttonStyle(OutlineButtonStyle())

            Button("Rest Now") {
                engine.restNow()
            }
            .buttonStyle(FilledButtonStyle())
        }
    }
}
