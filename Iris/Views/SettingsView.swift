//
//  SettingsView.swift
//  Iris
//
//  The settings face of the popover, organized into sections. Every control
//  binds straight to the shared TimerEngine, whose property observers persist
//  to UserDefaults immediately. The section body scrolls if it overflows.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var engine: TimerEngine
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    timerSection
                    SectionDivider()
                    soundSection
                    SectionDivider()
                    scheduleSection
                    SectionDivider()
                    wellnessSection
                    SectionDivider()
                    systemSection
                    SectionDivider()
                    quitButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(height: 420)
        }
        .frame(width: 280)
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
    }

    // MARK: - Sections

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Timer")
            SettingStepperRow(label: "Break interval", value: $engine.intervalMinutes,
                              range: 5...120, step: 5, display: "\(engine.intervalMinutes) min")
            SettingStepperRow(label: "Warn me", value: $engine.warningMinutes,
                              range: 1...5, step: 1, display: "\(engine.warningMinutes) min before")
            SettingStepperRow(label: "Rest duration", value: $engine.restDuration,
                              range: 10...60, step: 5, display: "\(engine.restDuration) sec")
        }
    }

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sound")
            SettingToggleRow(label: "Sound cues", isOn: $engine.soundEnabled)
            SettingToggleRow(label: "Ambient sound", isOn: $engine.ambientSoundEnabled)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Schedule")
            ScheduleSettingsSection()
        }
    }

    private var wellnessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Wellness")
            SettingToggleRow(label: "Posture nudges", isOn: $engine.postureNudgesEnabled)
            ChallengeSettingsSection()
        }
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "System")
            SettingToggleRow(label: "Launch at login", isOn: $engine.launchAtLogin)
            SettingToggleRow(label: "Auto-pause during calls", isOn: $engine.autoPauseDuringCalls)
        }
    }

    private var quitButton: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            Text("Quit Iris")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.red)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
        }
        .buttonStyle(.plain)
    }
}
