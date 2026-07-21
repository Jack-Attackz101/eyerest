//
//  CountdownRing.swift
//  Iris
//
//  A circular progress ring: a faint full-circle track with a bright arc drawn
//  on top. `progress` is the fraction of the arc to fill (0...1), starting at
//  12 o'clock and sweeping clockwise.
//

import SwiftUI

struct CountdownRing: View {
    var progress: Double
    var diameter: CGFloat
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
    }
}
