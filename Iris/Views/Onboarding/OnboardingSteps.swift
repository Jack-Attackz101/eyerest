//
//  OnboardingSteps.swift
//  Iris
//
//  The four individual steps shown inside OnboardingView.
//

import SwiftUI

// MARK: - Step 1: Welcome

struct OnboardingWelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image("IrisLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)

            Text("Welcome to Iris")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)

            Text("Every 20 minutes, your screen rests for 20 seconds. Your eyes will thank you.")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Color(hex: 0x999999))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Spacer()

            OnboardingPrimaryButton(title: "Let's set you up", action: onContinue)
                .padding(.horizontal, 40)
                .padding(.bottom, 12)
        }
    }
}

// MARK: - Step 2: How it works

struct OnboardingHowItWorksStep: View {
    let onContinue: () -> Void

    private struct Row: Identifiable {
        let id = UUID()
        let symbol: String
        let text: String
    }

    private let rows = [
        Row(symbol: "eye.fill",
            text: "A pill drops from your notch 2 minutes before each break"),
        Row(symbol: "moon.fill",
            text: "Your screen goes dark for 20 seconds. No skip — that's the point."),
        Row(symbol: "phone.down.fill",
            text: "On a call? Iris pauses automatically."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("How it works")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 26) {
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: row.symbol)
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .frame(width: 24)
                        Text(row.text)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: 0xCCCCCC))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: 340)

            Spacer()

            OnboardingPrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 40)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Step 3: Quick setup

struct OnboardingQuickSetupStep: View {
    @EnvironmentObject private var engine: TimerEngine
    @Binding var launchAtLogin: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 48)

            Text("Quick setup")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 0) {
                SettingStepperRow(label: "Break every", value: $engine.intervalMinutes,
                                  range: 5...120, step: 5, display: "\(engine.intervalMinutes) min")
                SettingStepperRow(label: "Rest for", value: $engine.restDuration,
                                  range: 10...60, step: 5, display: "\(engine.restDuration) sec")
                SettingToggleRow(label: "Launch at login", isOn: $launchAtLogin)
            }

            Spacer()

            OnboardingPrimaryButton(title: "Continue", action: onContinue)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Step 4: You're set

struct OnboardingYoureSetStep: View {
    @EnvironmentObject private var engine: TimerEngine
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white)

            Text("Iris is now running")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)

            Text("Look for the eye in your menu bar. Your first break is in \(engine.intervalMinutes) minutes.")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Color(hex: 0x999999))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Spacer()

            OnboardingPrimaryButton(title: "Start", action: onStart)
                .padding(.horizontal, 40)
                .padding(.bottom, 12)
        }
    }
}
