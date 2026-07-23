//
//  OnboardingView.swift
//  Iris
//
//  The 4-step first-launch welcome flow (see OnboardingWindowController).
//  Steps crossfade + slide horizontally; a skip control in the corner and
//  closing the window both resolve to the same "finish" path.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var engine: TimerEngine

    /// Called exactly once, however the flow ends (Start button, skip, or
    /// window close). `launchAtLogin` reflects the user's Step 3 choice (or
    /// this flow's default of `true` if they never reached that step).
    var onFinish: (_ launchAtLogin: Bool) -> Void

    @State private var step = 0
    @State private var launchAtLoginChoice = true

    private let totalSteps = 4

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                pageDots
            }

            skipButton
        }
        .frame(width: 460, height: 560)
        .background(Color.irisBackground)
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch step {
            case 0:
                OnboardingWelcomeStep(onContinue: advance)
            case 1:
                OnboardingHowItWorksStep(onContinue: advance)
            case 2:
                OnboardingQuickSetupStep(launchAtLogin: $launchAtLoginChoice, onContinue: advance)
            default:
                OnboardingYoureSetStep(onStart: finish)
            }
        }
        .id(step)
        .transition(.onboardingSlide)
    }

    private var skipButton: some View {
        Button(action: finish) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.4))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(10)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Circle()
                    .fill(i == step ? Color.white : Color(hex: 0x333333))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.bottom, 28)
    }

    private func advance() {
        withAnimation(.easeOut(duration: 0.35)) { step = min(step + 1, totalSteps - 1) }
    }

    private func finish() {
        onFinish(launchAtLoginChoice)
    }
}

// MARK: - Shared transition

private extension AnyTransition {
    static var onboardingSlide: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: OnboardingSlideModifier(x: 20, opacity: 0),
                identity: OnboardingSlideModifier(x: 0, opacity: 1)
            ),
            removal: .modifier(
                active: OnboardingSlideModifier(x: -20, opacity: 0),
                identity: OnboardingSlideModifier(x: 0, opacity: 1)
            )
        )
    }
}

private struct OnboardingSlideModifier: ViewModifier {
    let x: CGFloat
    let opacity: Double
    func body(content: Content) -> some View {
        content.offset(x: x).opacity(opacity)
    }
}

// MARK: - Shared primary button

struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
        }
        .buttonStyle(.plain)
    }
}
