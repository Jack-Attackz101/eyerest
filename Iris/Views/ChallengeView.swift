//
//  ChallengeView.swift
//  Iris
//
//  The full-screen physical-challenge overlay shown after unlock (Feature 7).
//

import SwiftUI

final class ChallengeModel: ObservableObject {
    @Published var visible = false
    /// Counts 5 → 0; the "Done" button only becomes tappable at 0.
    @Published var secondsUntilEnabled = 5
    var onDone: () -> Void = {}
}

struct ChallengeView: View {
    @ObservedObject var model: ChallengeModel
    let challenge: Challenge

    private var exercise: Exercise { Exercise.from(challenge.exercise) }

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 24) {
                Image(systemName: exercise.symbolName)
                    .font(.system(size: 88))
                    .foregroundStyle(.white)

                Text(exercise.rawValue)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)

                Text("× \(challenge.reps)")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundStyle(.white)

                doneButton
                    .padding(.top, 8)

                Text("Iris keeps your body and eyes healthy")
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .opacity(model.visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.6), value: model.visible)
    }

    private var doneButton: some View {
        Button {
            guard model.secondsUntilEnabled == 0 else { return }
            model.onDone()
        } label: {
            Text(model.secondsUntilEnabled > 0 ? "Done (\(model.secondsUntilEnabled))" : "Done")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 200, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(model.secondsUntilEnabled == 0 ? 1.0 : 0.55))
                )
        }
        .buttonStyle(.plain)
        .disabled(model.secondsUntilEnabled > 0)
    }
}
