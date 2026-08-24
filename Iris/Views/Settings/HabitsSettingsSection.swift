//
//  HabitsSettingsSection.swift
//  Iris
//
//  The Body tab's ongoing physical settings.
//
//  This used to be one run of eleven identical toggles with the scheduled
//  rituals mixed in, which made it the longest and least scannable tab. The
//  rituals moved to their own tab, and what is left is grouped by what the
//  setting does to you: the break itself, the nudges while you work, and the
//  camera, which is the only one that asks for a permission.
//
//  Every row carries an SF Symbol at the same weight and size, tinted with the
//  Body tint, so the list reads by shape as well as by label.
//

#if canImport(AppKit)
import AppKit
#endif
import SwiftUI

struct HabitsSettingsSection: View {
    @EnvironmentObject private var engine: TimerEngine

    private let tint = Color.irisTintWellness

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // MARK: During a break

            SectionHeader(title: "During a break")
            SettingsCard {
                SettingToggleRow(label: "Micro-stretch cards", isOn: $engine.stretchCardsEnabled,
                                 icon: "figure.flexibility", tint: tint,
                                 caption: "A stretch to follow for the first 15 seconds")
                if engine.stretchCardsEnabled {
                    SettingRow {
                        RowIcon(systemName: "target", tint: tint)
                        Text("Problem area")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.92))
                        Spacer(minLength: 8)
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
                SettingToggleRow(label: "Box breathing",
                                 isOn: $engine.boxBreathingEnabled,
                                 icon: "square.dashed", tint: tint,
                                 caption: BoxBreathing.fits(restDuration: engine.restDuration)
                                     ? "Four in, four hold, four out, four hold"
                                     : "Needs a rest of 16 seconds or longer")
            }

            // MARK: While you work

            SectionHeader(title: "While you work")
            SettingsCard {
                SettingRow {
                    RowIcon(systemName: "eye.slash", tint: tint)
                    Text("Blink reminders")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer(minLength: 8)
                    Picker("", selection: $engine.blinkStyle) {
                        ForEach(BlinkStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
                if engine.blinkStyle != .off {
                    SettingsChoiceRow(label: "Blink every", value: $engine.blinkIntervalSeconds,
                                      choices: BlinkEngine.allowedIntervals,
                                      range: 10...60, step: 10,
                                      format: { "\($0) sec" },
                                      icon: "timer", tint: tint)
                }
                SettingToggleRow(label: "Water reminders", isOn: $engine.waterRemindersEnabled,
                                 icon: "drop.fill", tint: tint)
                SettingToggleRow(label: "Stand-up mode", isOn: $engine.standUpModeEnabled,
                                 icon: "figure.stand", tint: tint,
                                 caption: "A nudge to get out of the chair each hour")
                SettingToggleRow(label: "Wrist relief timer", isOn: $engine.wristReliefEnabled,
                                 icon: "hand.raised.fill", tint: tint)
                if engine.wristReliefEnabled && !isTrusted {
                    accessibilityNotice
                }
                SettingToggleRow(label: "Scroll fatigue nudge", isOn: $engine.scrollFatigueEnabled,
                                 icon: "arrow.up.and.down", tint: tint)
                if engine.scrollFatigueEnabled && !isTrusted {
                    accessibilityNotice
                }
                SettingToggleRow(label: "Post-meeting reset", isOn: $engine.postMeetingResetEnabled,
                                 icon: "video.slash.fill", tint: tint,
                                 caption: "Look away after a call of 30 minutes or more")
            }

            // MARK: Camera

            SectionHeader(title: "Camera")
            SettingsCard {
                SettingToggleRow(
                    label: "Posture check (camera)",
                    isOn: $engine.postureCameraEnabled,
                    icon: "camera.fill",
                    tint: tint,
                    permissionNote: "Turning this on asks for camera access. Frames are read on your Mac by Apple's Vision framework to spot forward leaning, and are never stored and never uploaded."
                )
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
    }

    // MARK: - Sub-views

    private var isTrusted: Bool {
        #if canImport(AppKit)
        return AXIsProcessTrusted()
        #else
        return true
        #endif
    }

    /// Two of these need Accessibility to detect anything, and saying so where
    /// the switch is beats a nudge that silently never arrives.
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
                #if canImport(AppKit)
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                #endif
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.irisAccent)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
