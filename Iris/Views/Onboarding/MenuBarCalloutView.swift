//
//  MenuBarCalloutView.swift
//  Iris
//
//  Tiny transient callout shown once, right after onboarding completes, to
//  point the user at the menu bar icon they just heard about in Step 4.
//

import SwiftUI

struct MenuBarCalloutView: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text("Iris is here")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.85)))
    }
}
