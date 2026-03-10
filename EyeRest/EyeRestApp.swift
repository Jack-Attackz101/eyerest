import SwiftUI

@main
struct EyeRestApp: App {
    @StateObject private var timerManager = TimerManager.shared
    var body: some Scene {
        MenuBarExtra {
            MenuBarView().environmentObject(timerManager)
        } label: {
            Image(systemName: timerManager.isPaused ? "eye.slash" : "eye.fill")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
    }
    init() { TimerManager.shared.start() }
}
