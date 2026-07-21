//
//  PopoverRootView.swift
//  Iris
//
//  The cinematic popover: a looping video background, readability gradients,
//  the floating dashboard, a black fade-in on open, and a settings panel that
//  slides up over the video.
//

import SwiftUI

struct PopoverRootView: View {
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var dashboard: DashboardState

    @State private var showSettings = false
    @State private var fade: Double = 0

    private let size = CGSize(width: 320, height: 380)

    var body: some View {
        ZStack {
            VideoBackgroundView(state: dashboard)

            gradientOverlay
                .allowsHitTesting(false)

            MainView(showSettings: $showSettings)

            // Fade from black each time a new video begins.
            Color.black
                .opacity(fade)
                .allowsHitTesting(false)

            // Settings slides up from the bottom over the video.
            SettingsView(showSettings: $showSettings)
                .frame(width: size.width, height: size.height)
                .offset(y: showSettings ? 0 : size.height)
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: showSettings)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onChange(of: dashboard.sessionID) { _ in
            fade = 1
            withAnimation(.easeOut(duration: 0.4)) { fade = 0 }
        }
        .onChange(of: showSettings) { newValue in
            dashboard.settingsOpen = newValue
        }
    }

    /// Layer 2 — darken the top (where the timer lives) and add a subtle bottom vignette.
    private var gradientOverlay: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.6), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: size.height * 0.40)
            Spacer(minLength: 0)
            LinearGradient(colors: [.clear, .black.opacity(0.4)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: size.height * 0.20)
        }
    }
}
