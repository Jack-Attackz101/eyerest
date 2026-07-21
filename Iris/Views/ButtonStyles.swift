//
//  ButtonStyles.swift
//  Iris
//
//  The two action-button looks used in the popover: a white outline button and
//  a filled white button. Both are 32pt tall with a 10pt corner radius.
//

import SwiftUI

/// Outline style — white border, white text, transparent fill.
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

/// Filled style — solid white fill, black text.
struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
