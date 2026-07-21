//
//  ButtonStyles.swift
//  Iris
//
//  The two popover action-button looks: a neutral secondary button and the
//  accent-blue primary button. Both 34pt tall, 8pt corner radius.
//

import SwiftUI

/// Secondary — #1e1e1e fill, subtle white border, white text.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.irisButton)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.65 : 1.0)
    }
}

/// Primary — accent-blue fill, white text.
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.irisAccent)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
