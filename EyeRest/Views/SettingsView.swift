//
//  SettingsView.swift
//  EyeRest
//
//  The settings face of the popover. Every control binds straight to the shared
//  TimerEngine, whose property observers persist to UserDefaults immediately.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var engine: TimerEngine
    @Binding var showSettings: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            StepperRow(label: "Break interval",
                       value: $engine.intervalMinutes,
                       range: 5...120,
                       step: 5,
                       display: "\(engine.intervalMinutes) min")

            StepperRow(label: "Warn me",
                       value: $engine.warningMinutes,
                       range: 1...5,
                       step: 1,
                       display: "\(engine.warningMinutes) min before")

            StepperRow(label: "Rest duration",
                       value: $engine.restDuration,
                       range: 10...60,
                       step: 5,
                       display: "\(engine.restDuration) sec")

            ToggleRow(label: "Sound cues", isOn: $engine.soundEnabled)
            ToggleRow(label: "Launch at login", isOn: $engine.launchAtLogin)

            Divider()
                .overlay(Color.white.opacity(0.12))

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit EyeRest")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Button {
                showSettings = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Text("Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Rows

private struct StepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let display: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white)
            Spacer()
            Text(display)
                .font(.system(size: 12))
                .foregroundStyle(.gray)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}

private struct ToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}
