//
//  ChallengeView.swift
//  Iris
//
//  Full-screen physical challenge overlay. The Done button is hidden until the
//  exercise's hold duration elapses — the countdown ring and number make the
//  wait tangible. A small skip path is available but visible from the start.
//

import SwiftUI

// MARK: - ChallengeModel

final class ChallengeModel: ObservableObject {
    @Published var visible = false
    @Published var secondsRemaining: Int = 0
    @Published var doneEnabled = false
    @Published var streak: Int = 0
    @Published var showSkipConfirm = false

    var onDone: () -> Void = {}
    var onSkip: () -> Void = {}
}

// MARK: - ChallengeView

struct ChallengeView: View {
    @ObservedObject var model: ChallengeModel
    let exercise: Exercise

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            streakBadge
            mainContent
            skipCorner
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .opacity(model.visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.6), value: model.visible)
    }

    // MARK: - Streak badge (top-right)

    private var streakBadge: some View {
        VStack {
            HStack {
                Spacer()
                if model.streak > 0 {
                    Text("🔥 \(model.streak)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.trailing, 28)
                        .padding(.top, 28)
                }
            }
            Spacer()
        }
    }

    // MARK: - Central exercise content

    private var mainContent: some View {
        VStack(spacing: 20) {
            Image(systemName: exercise.symbolName)
                .font(.system(size: 80))
                .foregroundStyle(.white)

            Text(exercise.rawValue)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)

            Text(exercise.repsDisplay)
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.white)

            countdownBlock
                .padding(.top, 8)

            actionArea
                .frame(height: 64)
                .animation(.easeInOut(duration: 0.4), value: model.doneEnabled)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Countdown ring + number

    private var countdownBlock: some View {
        ZStack {
            CountdownRing(
                progress: model.doneEnabled ? 0 : ringProgress,
                diameter: 140,
                lineWidth: 6
            )
            if !model.doneEnabled {
                Text("\(model.secondsRemaining)")
                    .font(.system(size: 44, weight: .thin, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 140, height: 140)
    }

    private var ringProgress: Double {
        guard exercise.holdDuration > 0 else { return 0 }
        return Double(model.secondsRemaining) / Double(exercise.holdDuration)
    }

    // MARK: - Done button / hint (swaps at timer end)

    @ViewBuilder
    private var actionArea: some View {
        if model.doneEnabled {
            Button {
                model.onDone()
            } label: {
                Text("Done ✓")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 200, height: 48)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        } else {
            Text("Go! The Done button appears when time's up")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .transition(.opacity)
        }
    }

    // MARK: - Skip (bottom-right corner)

    private var skipCorner: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                skipArea
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var skipArea: some View {
        if model.showSkipConfirm {
            VStack(alignment: .trailing, spacing: 10) {
                Text(skipConfirmText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 220)

                HStack(spacing: 14) {
                    Button("Skip") { model.onSkip() }
                        .font(.system(size: 11))
                        .foregroundStyle(Color.irisTertiary)
                        .buttonStyle(.plain)

                    Button("Keep going") { model.showSkipConfirm = false }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.18))
                        )
                        .buttonStyle(.plain)
                }
            }
        } else {
            Button("Skip today") { model.showSkipConfirm = true }
                .font(.system(size: 11))
                .foregroundStyle(Color.irisTertiary)
                .buttonStyle(.plain)
        }
    }

    private var skipConfirmText: String {
        if model.streak > 0 {
            return "This resets your \(model.streak)-day streak. Skip anyway?"
        }
        return "Skip today's challenge?"
    }
}
