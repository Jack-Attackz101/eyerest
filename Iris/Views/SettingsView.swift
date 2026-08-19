//
//  SettingsView.swift
//  Iris
//
//  Settings face of the popover.
//
//  This was one scroll containing eight stacked sections inside a 380pt window,
//  so finding "launch at login" meant scrolling past the timer, sound, schedule,
//  focus, wellness and habits settings first. Everything was also the same shade
//  of grey, which made the list impossible to scan.
//
//  Now it is four tabs, each of which mostly fits without scrolling, with rows
//  grouped into cards and every row carrying a tinted icon so you can find
//  things by shape and colour instead of by reading each label in order.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var engine: TimerEngine
    @Binding var showSettings: Bool

    @State private var tab: SettingsTab = .timer

    var body: some View {
        VStack(spacing: 0) {
            header

            SettingsTabBar(selection: $tab)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab {
                    case .timer:    timerTab
                    case .focus:    focusTab
                    case .wellness: wellnessTab
                    case .system:   systemTab
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
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
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Settings")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Timer tab

    private var timerTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                SettingStepperRow(label: "Break every", value: $engine.intervalMinutes,
                                  range: 5...120, step: 5,
                                  display: "\(engine.intervalMinutes) min",
                                  icon: "clock.fill", tint: .irisTintTimer)
                SettingStepperRow(label: "Warn me", value: $engine.warningMinutes,
                                  range: 1...5, step: 1,
                                  display: "\(engine.warningMinutes) min before",
                                  icon: "bell.fill", tint: .irisTintTimer)
                SettingStepperRow(label: "Rest for", value: $engine.restDuration,
                                  range: 10...60, step: 5,
                                  display: "\(engine.restDuration) sec",
                                  icon: "eye.fill", tint: .irisTintTimer)
            }

            SectionHeader(title: "Break screen")
            SettingsCard {
                SettingRow {
                    RowIcon(systemName: "paintpalette.fill", tint: .irisTintTimer)
                    Text("Theme")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer(minLength: 8)
                    Picker("", selection: $engine.breakTheme) {
                        ForEach(BreakTheme.allCases) { theme in
                            HStack(spacing: 6) {
                                swatch(theme)
                                Text(theme.label)
                            }
                            .tag(theme)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }
            }

            SectionHeader(title: "Sound")
            SettingsCard {
                SettingToggleRow(label: "Sound cues", isOn: $engine.soundEnabled,
                                 icon: "speaker.wave.2.fill", tint: .irisTintSound)
                SettingToggleRow(label: "Ambient during rest", isOn: $engine.ambientSoundEnabled,
                                 icon: "water.waves", tint: .irisTintSound)
            }

            SectionHeader(title: "Schedule")
            SettingsCard {
                ScheduleSettingsSection()
            }
        }
    }

    /// A dot of the theme's own background, so the picker shows the look rather
    /// than only naming it.
    private func swatch(_ theme: BreakTheme) -> some View {
        Circle()
            .fill(theme == .random
                  ? AnyShapeStyle(AngularGradient(colors: BreakTheme.concrete.map(\.backgroundTop),
                                                  center: .center))
                  : AnyShapeStyle(theme.backgroundTop))
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
    }

    // MARK: - Focus tab

    private var focusTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            FocusSettingsSection(engine: engine)
        }
    }

    // MARK: - Body tab

    private var wellnessTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                SettingToggleRow(label: "Posture nudges", isOn: $engine.postureNudgesEnabled,
                                 icon: "figure.stand", tint: .irisTintWellness)
                if engine.postureNudgesEnabled {
                    SettingRow {
                        RowIcon(systemName: "repeat", tint: .irisTintWellness)
                        Text("Frequency")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.92))
                        Spacer(minLength: 8)
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

            HabitsSettingsSection()
        }
    }

    // MARK: - App tab

    private var systemTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                SettingToggleRow(label: "Launch at login", isOn: $engine.launchAtLogin,
                                 icon: "power", tint: .irisTintSystem)
                SettingToggleRow(label: "Pause during calls", isOn: $engine.autoPauseDuringCalls,
                                 icon: "video.fill", tint: .irisTintSystem,
                                 caption: "Skips breaks while a camera is in use")
                SettingToggleRow(label: "Wait for a natural gap", isOn: $engine.waitForNaturalGap,
                                 icon: "hand.raised.fill", tint: .irisTintSystem,
                                 caption: "Holds a break up to 2 min if you are typing")
                SettingToggleRow(
                    label: "Automatic updates",
                    isOn: Binding(
                        get: { UpdateChecker.shared.automaticallyChecksForUpdates },
                        set: { UpdateChecker.shared.automaticallyChecksForUpdates = $0 }
                    ),
                    icon: "arrow.triangle.2.circlepath", tint: .irisTintSystem
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

            LicenseSettingsSection()

#if DEBUG
            DemoSettingsSection()
#endif

            quitButton
        }
    }

    // MARK: - Quit

    private var quitButton: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .semibold))
                Text("Quit Iris")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Color(hex: 0xCC4444))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: 0x1A0A0A))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(hex: 0x3D1010), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
}
