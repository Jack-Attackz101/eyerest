//
//  ChallengeSettingsSection.swift
//  Iris
//
//  Morning / unlock physical-challenge settings (Feature 7), shown inline.
//

import SwiftUI

struct ChallengeSettingsSection: View {
    @EnvironmentObject private var engine: TimerEngine

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingToggleRow(label: "Physical challenge", isOn: $engine.challenge.isEnabled)

            if engine.challenge.isEnabled {
                exercisePicker
                repsStepper
                triggerControl

                if engine.challenge.triggerMode.usesMorningTime {
                    morningTimePicker
                }

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
            Text("Exercise").font(.system(size: 13)).foregroundStyle(Color.irisSecondary)
            Spacer()
            Picker("", selection: exerciseBinding) {
                ForEach(Exercise.allCases) { ex in Text(ex.rawValue).tag(ex) }
            }
            .labelsHidden().fixedSize().tint(Color.irisSecondary)
        }
        .frame(height: 36)
    }

    private var repsStepper: some View {
        HStack {
            Text("Reps").font(.system(size: 13)).foregroundStyle(Color.irisSecondary)
            Spacer()
            Text("\(engine.challenge.reps) \(currentExercise.repUnit)")
                .font(.system(size: 13)).foregroundStyle(.white)
            Stepper("", value: $engine.challenge.reps, in: 1...50, step: 1).labelsHidden()
        }
        .frame(height: 36)
    }

    private var triggerControl: some View {
        Picker("", selection: $engine.challenge.triggerMode) {
            ForEach(Challenge.TriggerMode.allCases) { mode in
                Text(shortLabel(mode)).tag(mode)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    private var morningTimePicker: some View {
        HStack {
            Text("After").font(.system(size: 13)).foregroundStyle(Color.irisSecondary)
            Spacer()
            DatePicker("", selection: morningTimeBinding, displayedComponents: .hourAndMinute)
                .labelsHidden().datePickerStyle(.stepperField).fixedSize()
        }
        .frame(height: 36)
    }

    // MARK: - Bindings / helpers

    private var currentExercise: Exercise { Exercise.from(engine.challenge.exercise) }

    private func shortLabel(_ mode: Challenge.TriggerMode) -> String {
        switch mode {
        case .morningOnly: return "Morning"
        case .everyUnlock: return "Every unlock"
        case .both: return "Both"
        }
    }

    private var exerciseBinding: Binding<Exercise> {
        Binding(
            get: { Exercise.from(engine.challenge.exercise) },
            set: { engine.challenge.exercise = $0.rawValue }
        )
    }

    /// Maps the morning start *hour* to/from a Date for the time picker.
    private var morningTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: engine.challenge.morningStartHour, minute: 0, second: 0, of: Date()
                ) ?? Date()
            },
            set: { engine.challenge.morningStartHour = Calendar.current.component(.hour, from: $0) }
        )
    }

    private var previewText: String {
        let c = engine.challenge
        let name = Exercise.from(c.exercise).rawValue.lowercased()
        let amount = "\(c.reps) \(name)"
        let timeString = Self.hourFormatter.string(
            from: Calendar.current.date(bySettingHour: c.morningStartHour, minute: 0, second: 0, of: Date()) ?? Date()
        )
        switch c.triggerMode {
        case .morningOnly:
            return "Iris will ask for \(amount) every morning after \(timeString)."
        case .everyUnlock:
            return "Iris will ask for \(amount) every time you unlock your Mac."
        case .both:
            return "Iris will ask for \(amount) on every unlock, and each morning after \(timeString)."
        }
    }
}
