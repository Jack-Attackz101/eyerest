//
//  SettingsComponents.swift
//  Iris
//
//  Small reusable building blocks for the reorganized settings panel.
//

import SwiftUI

/// Gray uppercase section header (10pt).
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Subtle divider between sections.
struct SectionDivider: View {
    var body: some View {
        Divider().overlay(Color.white.opacity(0.10))
    }
}

/// A label + value + stepper row.
struct SettingStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let display: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white)
            Spacer()
            Text(display)
                .font(.system(size: 12))
                .foregroundStyle(.gray)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}

/// A label + switch row.
struct SettingToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}
