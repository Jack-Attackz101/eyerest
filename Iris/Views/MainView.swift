//
//  MainView.swift
//  Iris
//
//  Default popover face: header, timer card (status pill, countdown, progress
//  bar, actions) and a floating stats row.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject private var stats = StatsEngine.shared
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeader(showSettings: $showSettings)

            VStack(spacing: 12) {
                timerCard
                if stats.breaksToday > 0 {
                    statsRow
                }
            }
            .padding(16)
        }
    }

    // MARK: - Timer card

    private var timerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatusPill(status: statusDescriptor)

            VStack(alignment: .leading, spacing: 2) {
                Text(engine.formattedTimeRemaining)
                    .font(.system(size: 52, weight: .thin, design: .monospaced))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("until your next break")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Color.irisTertiary)
            }

            progressBar

            HStack(spacing: 8) {
                Button(engine.isPaused ? "Resume" : "Pause") { engine.togglePause() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Rest Now") { engine.restNow() }
                    .buttonStyle(AccentButtonStyle())
            }
            .padding(.top, 2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.irisCard)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.irisBorder, lineWidth: 1))
        )
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.irisAccent)
                    .frame(width: max(0, geo.size.width * engine.intervalElapsedFraction))
            }
        }
        .frame(height: 2)
        .animation(.easeInOut(duration: 0.9), value: engine.intervalElapsedFraction)
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

    // MARK: - Status descriptor

    private var statusDescriptor: StatusPill.Descriptor {
        if engine.timerState == .warning {
            return .init(color: Color.irisAccent, text: "Break soon", pulsing: true)
        }
        switch engine.popoverStatus {
        case .scheduled(let label, _):
            return .init(color: .gray, text: label, pulsing: false)
        case .callDetected:
            return .init(color: .orange, text: "Call detected", pulsing: false)
        case .quietHours:
            return .init(color: .gray, text: "Quiet hours", pulsing: false)
        case .userPaused:
            return .init(color: .yellow, text: "Paused", pulsing: false)
        case .counting:
            return .init(color: .green, text: "Active", pulsing: false)
        }
    }
}

// MARK: - Shared popover header

struct PopoverHeader: View {
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
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

// MARK: - Status pill

struct StatusPill: View {
    struct Descriptor {
        let color: Color
        let text: String
        let pulsing: Bool
    }

    let status: Descriptor
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
                .opacity(status.pulsing && pulse ? 0.3 : 1.0)
                .onAppear {
                    guard status.pulsing else { return }
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            Text(status.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.irisSecondary)
        }
    }
}
