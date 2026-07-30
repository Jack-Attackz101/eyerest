//
//  SettingsView.swift
//  Iris
//
//  Settings face of the popover: a back header and scrollable, sectioned
//  controls bound directly to the shared TimerEngine.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var engine: TimerEngine
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    timerSection
                    soundSection
                    scheduleSection
                    focusSection
                    wellnessSection
                    habitsSection
                    systemSection
                    quitButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
        }
        .frame(width: 320, height: 380)
        .background(Color.irisBackground.opacity(0.97))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                showSettings = false
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Settings")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(16)
    }

    // MARK: - Sections

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Timer")
            SettingStepperRow(label: "Break every", value: $engine.intervalMinutes,
                              range: 5...120, step: 5, display: "\(engine.intervalMinutes) min")
            SettingStepperRow(label: "Warn me", value: $engine.warningMinutes,
                              range: 1...5, step: 1, display: "\(engine.warningMinutes) min before")
            SettingStepperRow(label: "Rest for", value: $engine.restDuration,
                              range: 10...60, step: 5, display: "\(engine.restDuration) sec")
        }
    }

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Sound")
            SettingToggleRow(label: "Sound cues", isOn: $engine.soundEnabled)
            SettingToggleRow(label: "Ambient during rest", isOn: $engine.ambientSoundEnabled)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Schedule")
            ScheduleSettingsSection()
        }
    }

    private var focusSection: some View {
        FocusSettingsSection(engine: engine)
    }

    private var wellnessSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Wellness")
            SettingToggleRow(label: "Posture nudges", isOn: $engine.postureNudgesEnabled)
            if engine.postureNudgesEnabled {
                SettingRow {
                    Text("Frequency")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.irisSecondary)
                    Spacer()
                    Picker("", selection: $engine.nudgeFrequency) {
                        ForEach(NudgeFrequency.allCases) { freq in
                            Text(freq.label).tag(freq)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
            }
            ChallengeSettingsSection()
        }
    }

    private var habitsSection: some View {
        HabitsSettingsSection()
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "System")
            SettingToggleRow(label: "Launch at login", isOn: $engine.launchAtLogin)
            SettingToggleRow(label: "Pause during calls", isOn: $engine.autoPauseDuringCalls)
            SettingToggleRow(
                label: "Check for updates automatically",
                isOn: Binding(
                    get: { UpdateChecker.shared.automaticallyChecksForUpdates },
                    set: { UpdateChecker.shared.automaticallyChecksForUpdates = $0 }
                )
            )
            SettingRow {
                Spacer()
                Button("Check for Updates…") {
                    UpdateChecker.shared.checkForUpdates()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.irisAccent)
                .buttonStyle(.plain)
            }
        }
    }

    private var quitButton: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            Text("Quit Iris")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: 0xCC4444))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: 0x1A0A0A))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: 0x3D1010), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}
