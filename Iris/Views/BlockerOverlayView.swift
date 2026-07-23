//
//  BlockerOverlayView.swift
//  Iris
//
//  Full-screen focus-blocker overlay. Shown when a blocked app or website is
//  detected. Auto-dismisses after 15 seconds via BlockerController.
//

import SwiftUI

// MARK: - Model

final class BlockerOverlayModel: ObservableObject {
    @Published var visible = false
    @Published var blockedName = ""

    var onBackToWork: () -> Void = {}
    var onLetMeIn: () -> Void = {}
}

// MARK: - View

struct BlockerOverlayView: View {
    @ObservedObject var model: BlockerOverlayModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "eye")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)

                Text("You're trying to focus right now.")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("\(model.blockedName) is on your block list")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.gray)
                    .padding(.bottom, 8)

                Button {
                    model.onBackToWork()
                } label: {
                    Text("Back to work")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 200, height: 48)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                }
                .buttonStyle(.plain)

                Button {
                    model.onLetMeIn()
                } label: {
                    Text("Let me in (5 min)")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 200, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .opacity(model.visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.4), value: model.visible)
    }
}
