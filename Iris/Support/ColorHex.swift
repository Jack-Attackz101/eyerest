//
//  ColorHex.swift
//  Iris
//
//  Small convenience for the hex colors used across the dark UI.
//

import SwiftUI

extension Color {
    /// Create an opaque sRGB color from a 24-bit hex value, e.g. `Color(hex: 0x111111)`.
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Iris design palette

extension Color {
    static let irisBackground = Color(hex: 0x0D0D0D)
    static let irisCard = Color(hex: 0x161616)
    static let irisButton = Color(hex: 0x1E1E1E)
    static let irisAccent = Color(hex: 0x4B6BFB)
    static let irisSecondary = Color(hex: 0x888888)
    static let irisTertiary = Color(hex: 0x666666)
    static let irisSectionLabel = Color(hex: 0x444444)
    static let irisBorder = Color.white.opacity(0.05)
}
