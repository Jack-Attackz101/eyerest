//
//  PopoverRootView.swift
//  Iris
//
//  The popover container: crossfades between the main state and the settings
//  panel. Each face renders its own header.
//

import SwiftUI

struct PopoverRootView: View {
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.irisBackground

            if showSettings {
                SettingsView(showSettings: $showSettings)
                    .transition(.opacity)
            } else {
                MainView(showSettings: $showSettings)
                    .transition(.opacity)
            }
        }
        .frame(width: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.2), value: showSettings)
    }
}
