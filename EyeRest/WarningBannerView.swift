import SwiftUI
struct WarningBannerView: View {
    @EnvironmentObject private var tm: TimerManager
    let onDismiss: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.trianglebadge.exclamationmark").font(.system(size: 22, weight: .semibold)).foregroundColor(Color(hex: "#FF6B35")).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Eye Break Soon").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Text("Screen blackout in \(Int(tm.timeUntilNextRest)/60):\(String(format:"%02d",Int(tm.timeUntilNextRest)%60))")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#888888"))
            }
            Spacer()
            Button { onDismiss() } label: { Text("Dismiss").font(.system(size: 12)).foregroundColor(Color(hex: "#888888")) }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 12).frame(width: 320, height: 72)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#1A1A1A")).shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 4))
    }
}
