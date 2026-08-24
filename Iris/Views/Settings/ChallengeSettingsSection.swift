//
//  ChallengeSettingsSection.swift
//  Iris
//
//  Morning physical-challenge settings: exercise picker (with "Surprise me"),
//  wake-up time, bedtime, and a live preview of the full flow.
//

import SwiftUI

struct ChallengeSettingsSection: View {
    @EnvironmentObject private var engine: TimerEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingToggleRow(label: "Physical challenge",
                             isOn: $engine.challenge.isEnabled,
                             icon: "figure.run", tint: .irisTintSchedule,
                             caption: "Movement before your Mac unlocks")

            if engine.challenge.isEnabled {
                exercisePicker
                wakeTimePicker
                bedtimePicker

                Text(previewText)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.irisTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Controls

    private var exercisePicker: some View {
        HStack {
            Text("Exercise")
                .font(.system(size: 13))
                .foregroundStyle(Color.irisSecondary)
            Spacer()
            Picker("", selection: $engine.challenge.exerciseID) {
                Text("Surprise me").tag(Challenge.surpriseMeID)
                ForEach(Exercise.allCases) { ex in
                    Text(ex.pickerLabel).tag(ex.rawValue)
                }
            }
            .labelsHidden()
            .fixedSize()
            .tint(Color.irisSecondary)
        }
        .frame(height: 36)
    }

    private var wakeTimePicker: some View {
        HStack {
            Text("Wake-up time")
                .font(.system(size: 13))
                .foregroundStyle(Color.irisSecondary)
            Spacer()
            DatePicker("", selection: $engine.challenge.wakeTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.stepperField)
                .fixedSize()
        }
        .frame(height: 36)
    }

    private var bedtimePicker: some View {
        HStack {
            Text("Bedtime")
                .font(.system(size: 13))
                .foregroundStyle(Color.irisSecondary)
            Spacer()
            DatePicker("", selection: $engine.challenge.bedtime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.stepperField)
                .fixedSize()
        }
        .frame(height: 36)
    }

    // MARK: - Preview text

    private var previewText: String {
        let c = engine.challenge
        let wakeStr = formatted(c.wakeTime)

        if c.isSurpriseMe {
            return "Every morning after \(wakeStr) and before \(formatted(c.bedtime)): a random desk-friendly exercise."
        }

        let ex = Exercise.from(c.exerciseID)
        return "Every morning after \(wakeStr): \(ex.repsDescription) \(ex.rawValue.lowercased()) (\(ex.holdDuration) second timer)"
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}
