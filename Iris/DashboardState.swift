//
//  DashboardState.swift
//  Iris
//
//  Drives the cinematic popover: which environment video is playing, whether
//  the popover is open, and whether the settings panel is covering it.
//

import Foundation

final class DashboardState: ObservableObject {

    enum Environment: String, CaseIterable {
        case mountain, forest, beach

        var videoName: String { rawValue }

        var label: String {
            switch self {
            case .mountain: return "🏔 Mountain"
            case .forest: return "🌲 Forest"
            case .beach: return "🌊 Beach"
            }
        }
    }

    @Published private(set) var environment: Environment = .mountain
    @Published private(set) var isOpen = false
    @Published var settingsOpen = false
    /// Bumped on every open so the view can replay the fade-from-black.
    @Published private(set) var sessionID = 0

    private var lastEnvironment: Environment?

    /// The video should only run while the popover is open and settings is closed.
    var shouldPlay: Bool { isOpen && !settingsOpen }

    /// Called each time the popover opens: pick a fresh random environment
    /// (never the same one twice in a row).
    func popoverOpened() {
        let choices = Environment.allCases.filter { $0 != lastEnvironment }
        let next = choices.randomElement() ?? Environment.allCases.randomElement()!
        lastEnvironment = next
        environment = next
        settingsOpen = false
        sessionID += 1
        isOpen = true
    }

    func popoverClosed() {
        isOpen = false
        settingsOpen = false
    }
}
