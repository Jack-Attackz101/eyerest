import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(red: Double((int >> 16) & 0xFF)/255,
                  green: Double((int >> 8)  & 0xFF)/255,
                  blue:  Double(int         & 0xFF)/255)
    }
    static let eyeAccent  = Color(hex: "#FF6B35")
    static let eyeGray    = Color(hex: "#888888")
    static let eyeSurface = Color(hex: "#1C1C1C")
    static let eyeBG      = Color(hex: "#111111")
}

struct MenuBarView: View {
    @EnvironmentObject private var tm: TimerManager
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08))
            countdown
            actionButtons
            Divider().background(Color.white.opacity(0.08))
            settingsSection
            Divider().background(Color.white.opacity(0.08))
            footerSection
        }
        .frame(width: 300)
        .background(Color.eyeBG)
        .foregroundColor(.white)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.fill").font(.system(size: 20, weight: .semibold)).foregroundColor(.eyeAccent)
            VStack(alignment: .leading, spacing: 1) {
                Text("EyeRest").font(.system(size: 15, weight: .bold))
                Text("20-20-20 Rule").font(.system(size: 11)).foregroundColor(.eyeGray)
            }
            Spacer()
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var countdown: some View {
        VStack(spacing: 4) {
            Text(tm.isResting ? "Resting now…" : (tm.isPaused ? "Paused" : "Next rest in"))
                .font(.system(size: 11)).foregroundColor(.eyeGray)
            Text(fmt(tm.isResting ? tm.restSecondsRemaining : Int(tm.timeUntilNextRest)))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundColor(tm.isResting ? .eyeAccent : .white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color.eyeSurface.opacity(0.6))
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            MBBtn(title: tm.isPaused ? "Resume" : "Pause", icon: tm.isPaused ? "play.fill" : "pause.fill", accent: false) { tm.togglePause() }.disabled(tm.isResting)
            MBBtn(title: "Rest Now", icon: "eye.slash.fill", accent: true) { tm.triggerRestNow() }.disabled(tm.isResting || tm.isPaused)
            MBBtn(title: "Reset", icon: "arrow.counterclockwise", accent: false) { tm.resetCycle() }.disabled(tm.isResting)
        }.padding(.horizontal, 12).padding(.vertical, 10)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings").font(.system(size: 11, weight: .semibold)).foregroundColor(.eyeGray).padding(.horizontal, 16).padding(.top, 10)
            HStack {
                Label("Rest every", systemImage: "clock").font(.system(size: 12)).foregroundColor(.eyeGray)
                Spacer()
                Stepper("\(tm.intervalMinutes) min", value: Binding(get: { tm.intervalMinutes }, set: { tm.intervalMinutes = max(5, min(120, $0)) }), in: 5...120).font(.system(size: 12))
            }.padding(.horizontal, 16)
            HStack {
                Label("Warn before", systemImage: "bell").font(.system(size: 12)).foregroundColor(.eyeGray)
                Spacer()
                Stepper("\(tm.warningMinutes) min", value: Binding(get: { tm.warningMinutes }, set: { tm.warningMinutes = max(1, min(10, $0)) }), in: 1...10).font(.system(size: 12))
            }.padding(.horizontal, 16)
            HStack {
                Label("Duration", systemImage: "timer").font(.system(size: 12)).foregroundColor(.eyeGray)
                Spacer()
                Stepper("\(tm.restDurationSeconds)s", value: Binding(get: { tm.restDurationSeconds }, set: { tm.restDurationSeconds = max(20, min(60, $0)) }), in: 20...60).font(.system(size: 12))
            }.padding(.horizontal, 16).padding(.bottom, 10)
        }
    }

    private var footerSection: some View {
        VStack(spacing: 0) {
            Toggle(isOn: Binding(get: { tm.launchAtLogin }, set: { tm.launchAtLogin = $0 })) {
                Label("Launch at login", systemImage: "power").font(.system(size: 12))
            }.toggleStyle(.switch).padding(.horizontal, 16).padding(.vertical, 10)
            Divider().background(Color.white.opacity(0.06))
            Button { NSApplication.shared.terminate(nil) } label: {
                HStack { Image(systemName: "xmark.circle"); Text("Quit EyeRest") }
                    .font(.system(size: 12)).foregroundColor(.eyeGray).frame(maxWidth: .infinity).padding(.vertical, 10)
            }.buttonStyle(.plain)
        }
    }

    private func fmt(_ s: Int) -> String { String(format: "%02d:%02d", s/60, s%60) }
}

struct MBBtn: View {
    let title: String; let icon: String; let accent: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) { Image(systemName: icon); Text(title) }
                .font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 7).frame(maxWidth: .infinity)
                .background(accent ? Color.eyeAccent : Color.white.opacity(0.1)).cornerRadius(8)
        }.buttonStyle(.plain)
    }
}
