//
//  SettingsComponents.swift
//  Iris
//
//  Reusable building blocks for the redesigned settings panel.
//

import SwiftUI

/// Uppercase section label — SF Pro Medium 10pt, #444.
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .medium))
            .tracking(0.8)
            .foregroundStyle(Color.irisSectionLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)
    }
}

/// A 40pt row with a subtle bottom border.
struct SettingRow<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack { content }
                .frame(height: 40)
            Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
        }
    }
}

/// Label + value + stepper. The value "pops" briefly when it changes.
struct SettingStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let display: String

    @State private var pop: CGFloat = 1.0

    var body: some View {
        SettingRow {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.irisSecondary)
            Spacer()
            Text(display)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .scaleEffect(pop)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .onChange(of: value) { _ in
                    pop = 1.05
                    withAnimation(.easeOut(duration: 0.15)) { pop = 1.0 }
                }
        }
    }
}

/// Label + accent-tinted switch.
struct SettingToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        SettingRow {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.irisSecondary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.irisAccent)
                .controlSize(.small)
        }
    }
}
