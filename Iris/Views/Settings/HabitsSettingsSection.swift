//
//  HabitsSettingsSection.swift
//  Iris
//
//  Settings UI for all 12 new habit + permission features.
//

import SwiftUI
import AppKit

struct HabitsSettingsSection: View {
    @EnvironmentObject private var engine: TimerEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Habits")

            // Feature 1: Micro-stretch cards
            SettingToggleRow(label: "Micro-stretch cards", isOn: $engine.stretchCardsEnabled)

            // Feature 3: Pick your problem area (visible when stretch cards on)
            if engine.stretchCardsEnabled {
                SettingRow {
                    Text("Problem area")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.irisSecondary)
                    Spacer()
                    Picker("", selection: $engine.problemArea) {
                        ForEach(ProblemArea.allCases) { area in
                            Text(area.label).tag(area)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
            }

            // Feature 2: Water reminders
            SettingToggleRow(label: "Water reminders", isOn: $engine.waterRemindersEnabled)

            // Feature 4: Stand-up mode
            SettingToggleRow(label: "Stand-up mode", isOn: $engine.standUpModeEnabled)

            // Feature 5: Late-night guard
            SettingToggleRow(label: "Late-night guard", isOn: $engine.lateNightGuardEnabled)
            if engine.lateNightGuardEnabled {
                lateNightHourRow
            }

            // Feature 6: Brightness check
            SettingToggleRow(label: "Brightness check", isOn: $engine.brightnessCheckEnabled)

            // Feature 7: Wind-down
            SettingToggleRow(label: "End-of-day wind-down", isOn: $engine.windDownEnabled)

            // Feature 8: Desk reset checklist
            SettingToggleRow(label: "Desk reset checklist", isOn: $engine.deskResetEnabled)

            SectionHeader(title: "Accessibility")
                .padding(.top, 10)

            // Feature 9: Wrist relief timer
            SettingToggleRow(label: "Wrist relief timer", isOn: $engine.wristReliefEnabled)
            if engine.wristReliefEnabled && !AXIsProcessTrusted() {
                accessibilityNotice
            }

            // Feature 10: Post-meeting reset
            SettingToggleRow(label: "Post-meeting reset", isOn: $engine.postMeetingResetEnabled)

            // Feature 11: Scroll fatigue nudge
            SettingToggleRow(label: "Scroll fatigue nudge", isOn: $engine.scrollFatigueEnabled)
            if engine.scrollFatigueEnabled && !AXIsProcessTrusted() {
                accessibilityNotice
            }

            SectionHeader(title: "Camera")
                .padding(.top, 10)

            // Feature 12: Posture camera check
            postureCameraSection
        }
    }

    // MARK: - Sub-views

    private var lateNightHourRow: some View {
        SettingRow {
            Text("After")
                .font(.system(size: 13))
                .foregroundStyle(Color.irisSecondary)
            Spacer()
            Picker("", selection: $engine.lateNightHour) {
                ForEach([19, 20, 21, 22, 23], id: \.self) { hour in
                    Text(hourLabel(hour)).tag(hour)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
        }
    }

    private var accessibilityNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.system(size: 11))
                .foregroundStyle(Color.irisAccent)
            Text("Needs Accessibility permission in System Settings.")
                .font(.system(size: 11))
                .foregroundStyle(Color.irisTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Open") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.irisAccent)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var postureCameraSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !engine.postureCameraEnabled {
                cameraExplanation
            }
            SettingToggleRow(label: "Posture check (camera)", isOn: $engine.postureCameraEnabled)
                .onChange(of: engine.postureCameraEnabled) { enabled in
                    if enabled {
                        Task { @MainActor in
                            PostureCameraEngine.shared.requestCameraAndBegin()
                        }
                    } else {
                        Task { @MainActor in PostureCameraEngine.shared.stop() }
                    }
                }
        }
    }

    private var cameraExplanation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Uses your camera to detect forward leaning. Frames are never stored or transmitted.")
                .font(.system(size: 11))
                .foregroundStyle(Color.irisTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
    }

    // MARK: - Helpers

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}
