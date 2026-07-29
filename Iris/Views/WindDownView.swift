//
//  WindDownView.swift
//  Iris
//
//  60-second end-of-day decompression overlay: breathing guide + countdown.
//

import SwiftUI

final class WindDownModel: ObservableObject {
    @Published var visible = false
    @Published var secondsRemaining = 60
    @Published var phase: BreathPhase = .inhale

    enum BreathPhase: String {
        case inhale = "Breathe in"
        case hold   = "Hold"
        case exhale = "Breathe out"
        case pause  = "Pause"

        var duration: Int {
            switch self {
            case .inhale: return 4
            case .hold:   return 4
            case .exhale: return 6
            case .pause:  return 2
            }
        }

        var next: BreathPhase {
            switch self {
            case .inhale: return .hold
            case .hold:   return .exhale
            case .exhale: return .pause
            case .pause:  return .inhale
            }
        }

        var color: Color {
            switch self {
            case .inhale: return .teal.opacity(0.7)
            case .hold:   return .white.opacity(0.5)
            case .exhale: return .blue.opacity(0.5)
            case .pause:  return .gray.opacity(0.4)
            }
        }
    }
}

struct WindDownView: View {
    @ObservedObject var model: WindDownModel
    var onDismiss: () -> Void

    @State private var phaseSeconds = 0
    @State private var circleScale: CGFloat = 0.7

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Text("Wind Down")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))

                ZStack {
                    Circle()
                        .fill(model.phase.color)
                        .frame(width: 140, height: 140)
                        .scaleEffect(circleScale)
                        .animation(.easeInOut(duration: Double(model.phase.duration)), value: circleScale)

                    VStack(spacing: 4) {
                        Text(model.phase.rawValue)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }

                Text("\(model.secondsRemaining)")
                    .font(.system(size: 52, weight: .thin, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))

                Text("seconds left")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(.white.opacity(0.35))

                Button("Done") { onDismiss() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1), in: Capsule())
                    .buttonStyle(.plain)
            }

            VStack {
                Spacer()
                Text("iris")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.white.opacity(0.1))
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startBreathPhase() }
        .onChange(of: model.phase) { _ in startBreathPhase() }
        .opacity(model.visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.5), value: model.visible)
    }

    private func startBreathPhase() {
        circleScale = model.phase == .inhale || model.phase == .hold ? 1.0 : 0.65
    }
}
