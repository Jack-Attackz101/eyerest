//
//  MainView.swift
//  Iris
//
//  The floating dashboard layers drawn over the video: header, status pill,
//  timer, stats line, control pills, and the environment indicator.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var dashboard: DashboardState
    @ObservedObject private var stats = StatsEngine.shared
    @Binding var showSettings: Bool

    @State private var envIndicatorOpacity: Double = 1

    var body: some View {
        ZStack {
            content
            environmentIndicator
        }
        .frame(width: 320, height: 380)
    }

    // MARK: - Main column

    private var content: some View {
        VStack(spacing: 0) {
            header
            HStack {
                Spacer()
                StatusPill(descriptor: statusDescriptor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer(minLength: 8)
            timerBlock
            Spacer()
            Spacer()

            if stats.breaksToday > 0 {
                statsLine.padding(.bottom, 10)
            }
            controls.padding(.bottom, 20)
        }
    }

    // MARK: - Layer 3: header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.9))
            Text("iris")
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Layer 4: timer

    private var timerBlock: some View {
        VStack(spacing: 4) {
            Text(engine.formattedTimeRemaining)
                .font(.system(size: 58, weight: .thin, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 2)
            Text("until your next break")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Stats line

    private var statsLine: some View {
        Text("🔥 \(stats.currentStreak) day streak  ·  \(stats.breaksToday) today")
            .font(.system(size: 11, weight: .light))
            .foregroundStyle(.white.opacity(0.5))
    }

    // MARK: - Layer 5: controls

    private var controls: some View {
        HStack(spacing: 10) {
            Button(engine.isPaused ? "Resume" : "Pause") { engine.togglePause() }
                .buttonStyle(FrostedPillStyle())
            Button("Rest Now") { engine.restNow() }
                .buttonStyle(SolidPillStyle())
        }
    }

    // MARK: - Environment indicator (bottom-left, fades after 3s)

    private var environmentIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Text(dashboard.environment.label)
                    .font(.system(size: 10, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                Spacer()
            }
            .padding(.leading, 12)
            .padding(.bottom, 16)
        }
        .opacity(envIndicatorOpacity)
        .task(id: dashboard.sessionID) {
            envIndicatorOpacity = 1
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.easeOut(duration: 0.5)) { envIndicatorOpacity = 0 }
        }
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

// MARK: - Status pill (Layer 6)

struct StatusPill: View {
    struct Descriptor {
        let color: Color
        let text: String
        let pulsing: Bool
    }

    let descriptor: Descriptor
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(descriptor.color)
                .frame(width: 6, height: 6)
                .opacity(descriptor.pulsing && pulse ? 0.3 : 1)
                .onAppear {
                    guard descriptor.pulsing else { return }
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            Text(descriptor.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Control pill styles

/// Frosted translucent pill (Pause/Resume).
struct FrostedPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 110, height: 36)
            .background {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color.white.opacity(0.15))   // frosted tint, behind the label
            }
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Solid light pill (Rest Now).
struct SolidPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.black)
            .frame(width: 110, height: 36)
            .background(Color.white.opacity(0.9), in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
