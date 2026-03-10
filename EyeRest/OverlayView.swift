import SwiftUI
struct OverlayView: View {
    @EnvironmentObject private var tm: TimerManager
    @State private var breathScale: CGFloat = 1.0
    @State private var skipAvailable = false
    @State private var skipCountdown = 5
    private var progress: CGFloat { tm.restDurationSeconds > 0 ? CGFloat(tm.restSecondsRemaining) / CGFloat(tm.restDurationSeconds) : 0 }
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "eye.slash.fill").font(.system(size: 64, weight: .light)).foregroundColor(.white)
                    .scaleEffect(breathScale).animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: breathScale)
                VStack(spacing: 8) {
                    Text("Rest your eyes").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                    Text("Look at something 20 feet away").font(.system(size: 18)).foregroundColor(Color(hex: "#888888"))
                }
                ZStack {
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 5).frame(width: 120, height: 120)
                    Circle().trim(from: 0, to: progress).stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 120, height: 120).rotationEffect(.degrees(-90)).animation(.linear(duration: 1), value: progress)
                    Text("\(tm.restSecondsRemaining)").font(.system(size: 56, weight: .bold, design: .monospaced)).foregroundColor(.white).contentTransition(.numericText(countsDown: true))
                }
                Spacer()
                skipBtn.padding(.bottom, 40)
            }
        }
        .onAppear { breathScale = 1.05; startSkip() }
    }
    @ViewBuilder private var skipBtn: some View {
        if skipAvailable {
            Button { tm.skipCurrentRest() } label: {
                Text("Skip").font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "#888888"))
                    .padding(.horizontal, 20).padding(.vertical, 8).background(Color.white.opacity(0.08)).cornerRadius(20)
            }.buttonStyle(.plain).transition(.opacity)
        } else {
            Text("Skip available in \(skipCountdown)s").font(.system(size: 13)).foregroundColor(Color(hex: "#555555"))
        }
    }
    private func startSkip() {
        skipCountdown = 5; skipAvailable = false
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            Task { @MainActor in
                if self.skipCountdown > 1 { self.skipCountdown -= 1 }
                else { t.invalidate(); withAnimation { self.skipAvailable = true } }
            }
        }
    }
}
