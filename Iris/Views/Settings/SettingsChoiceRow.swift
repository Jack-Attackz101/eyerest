//
//  SettingsChoiceRow.swift
//  Iris
//
//  The replacement for the steppers.
//
//  A stepper makes you click a spinner six times to go from 20 minutes to 50,
//  shows the value in a separate place from the control, and is the most dated
//  thing on the platform. Almost every numeric setting here is really a choice
//  between four sensible values, so it is presented as one: four pills, tap the
//  one you want. "Custom" opens the full range for the few people who want 37
//  minutes, and keeps working for anyone who already set an odd value.
//
//  Sized for the 320pt popover: four pills across the content width, so each is
//  around 60pt, which fits "120 min" at 11pt.
//

import SwiftUI

struct SettingsChoiceRow: View {
    let label: String
    @Binding var value: Int
    /// The handful of values worth one tap.
    let choices: [Int]
    /// Everything else, for the custom slider.
    let range: ClosedRange<Int>
    let step: Int
    /// How a value reads, for example 20 -> "20 min".
    let format: (Int) -> String
    var icon: String? = nil
    var tint: Color = .irisAccent

    @State private var showingCustom = false

    /// True when the current value is not one of the offered choices, which is
    /// how a custom value stays visible instead of silently snapping.
    private var isCustom: Bool { !choices.contains(value) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if let icon { RowIcon(systemName: icon, tint: tint) }
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer(minLength: 6)
                Text(format(value))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
            .padding(.horizontal, 12)
            .padding(.top, 11)
            .padding(.bottom, 8)

            HStack(spacing: 4) {
                ForEach(choices, id: \.self) { choice in
                    pill(text: format(choice), selected: value == choice && !showingCustom) {
                        value = choice
                        showingCustom = false
                    }
                }
                pill(text: "Custom", selected: isCustom || showingCustom) {
                    showingCustom.toggle()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, showingCustom ? 6 : 11)

            if showingCustom {
                // The full range, with the value above the thumb rather than
                // beside it, so the number is where you are looking.
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = Int(($0 / Double(step)).rounded()) * step }
                    ),
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: Double(step)
                )
                .controlSize(.small)
                .tint(tint)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            Rectangle().fill(Color.irisDivider).frame(height: 1)
        }
    }

    private func pill(text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(selected ? .white : Color.irisSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selected ? tint.opacity(0.9) : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }
}
