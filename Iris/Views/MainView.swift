//
//  MainView.swift
//  Iris
//
//  Default popover face: header, countdown ring (or a suspension status),
//  a slim stats row, and the Pause/Rest Now buttons.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject private var stats = StatsEngine.shared
    @Binding var showSettings: Bool

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(spacing: 16) {
            header
            centerSection
            if stats.breaksToday >= 1 {
                statsRow
            }
            actionButtons
        }
        .padding(20)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Iris")
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

    // MARK: - Center (countdown ring or suspension status)

    @ViewBuilder
    private var centerSection: some View {
        switch engine.popoverStatus {
        case .counting, .userPaused:
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

        case .callDetected:
            statusView(icon: "video.fill", title: "Paused — call detected", subtitle: nil)

        case .quietHours:
            statusView(icon: "moon.fill", title: "Quiet hours active", subtitle: nil)

        case let .scheduled(label, endsAt):
            statusView(icon: "calendar",
                       title: "Paused — \(label)",
                       subtitle: "ends at \(Self.timeFormatter.string(from: endsAt))")
        }
    }

    private func statusView(icon: String, title: String, subtitle: String?) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.85))
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
        }
        .frame(height: 138)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats row (Feature 2)

    private var statsRow: some View {
        HStack {
            Label {
                Text("\(stats.currentStreak) day\(stats.currentStreak == 1 ? "" : "s")")
            } icon: {
                Image(systemName: "flame.fill")
            }
            Spacer()
            Label {
                Text("\(stats.breaksToday) today")
            } icon: {
                Image(systemName: "eye.fill")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.gray)
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
