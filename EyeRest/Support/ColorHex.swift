//
//  ColorHex.swift
//  EyeRest
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
