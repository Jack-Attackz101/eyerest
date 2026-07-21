//
//  MainView.swift
//  Iris
//
//  Default popover face: header, countdown ring, action buttons, and an
//  optional stats row. Compact — the view hugs its content.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject private var stats = StatsEngine.shared
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeader(showSettings: $showSettings)

            VStack(spacing: 16) {
                ringSection
                actionButtons
                if stats.breaksToday > 0 {
                    statsRow
                }
            }
            .padding(16)
        }
    }

    // MARK: - Countdown ring

    private var ringSection: some View {
        VStack(spacing: 8) {
            ZStack {
                CountdownRing(progress: engine.intervalElapsedFraction, diameter: 130, lineWidth: 3)
                Text(engine.formattedTimeRemaining)
                    .font(.system(size: 30, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            Text("until your next break")
                .font(.system(size: 12))
                .foregroundStyle(Color.irisSecondary)
        }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(engine.isPaused ? "Resume" : "Pause") { engine.togglePause() }
                .buttonStyle(SecondaryButtonStyle())
            Button("Rest Now") { engine.restNow() }
                .buttonStyle(AccentButtonStyle())
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack {
            Text("🔥 \(stats.currentStreak) day streak")
            Spacer()
            Text("\(stats.breaksToday) breaks today")
        }
        .font(.system(size: 11))
        .foregroundStyle(Color.irisTertiary)
        .padding(.horizontal, 4)
    }
}

// MARK: - Shared popover header

struct PopoverHeader: View {
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                Text("iris")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.irisSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Rectangle()
                .fill(Color.irisBorder)
                .frame(height: 1)
        }
    }
}
