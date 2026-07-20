//
//  PopoverRootView.swift
//  EyeRest
//
//  The popover's container. Holds the dark #111111 background and crossfades
//  between the main countdown view and the settings panel — no navigation
//  stack, just a @State flag.
//

import SwiftUI

struct PopoverRootView: View {
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color(hex: 0x111111)

            if showSettings {
                SettingsView(showSettings: $showSettings)
                    .transition(.opacity)
            } else {
                MainView(showSettings: $showSettings)
                    .transition(.opacity)
            }
        }
        .frame(width: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showSettings)
    }
}
