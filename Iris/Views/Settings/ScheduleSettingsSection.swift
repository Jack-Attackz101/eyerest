//
//  ScheduleSettingsSection.swift
//  Iris
//
//  Quiet Hours (Feature 4) + Schedule Blocks (Feature 6) settings, shown inline.
//

import SwiftUI

struct ScheduleSettingsSection: View {
    @EnvironmentObject private var engine: TimerEngine
    @State private var isAdding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // --- Quiet Hours ---
            SettingToggleRow(label: "Quiet hours", isOn: $engine.quietHoursEnabled)

            if engine.quietHoursEnabled {
                HStack {
                    Text("From")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    DatePicker("", selection: $engine.quietHoursStart, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.stepperField)
                        .fixedSize()
                }
                HStack {
                    Text("To")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    DatePicker("", selection: $engine.quietHoursEnd, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.stepperField)
                        .fixedSize()
                }
            }

            // --- Schedule Blocks ---
            HStack {
                Text("Schedule blocks")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation { isAdding.toggle() }
                } label: {
                    Image(systemName: isAdding ? "xmark.circle" : "plus.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
            }

            if engine.scheduleBlocks.isEmpty && !isAdding {
                Text("No schedule blocks. Add one to automatically pause Iris during meetings, lunch, or after hours.")
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach($engine.scheduleBlocks) { $block in
                blockRow($block)
            }

            if isAdding {
                BlockEditor { newBlock in
                    engine.addScheduleBlock(newBlock)
                    withAnimation { isAdding = false }
                } onCancel: {
                    withAnimation { isAdding = false }
                }
            }
        }
    }

    private func blockRow(_ block: Binding<ScheduleBlock>) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.wrappedValue.label)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                Text(subtitle(block.wrappedValue))
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }
            Spacer()
            Toggle("", isOn: block.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            Button {
                let id = block.wrappedValue.id
                engine.scheduleBlocks.removeAll { $0.id == id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func subtitle(_ block: ScheduleBlock) -> String {
        let time = String(format: "%02d:%02d", block.startHour, block.startMinute)
        return "\(time) · \(block.durationMinutes) min · \(block.recurrence.displayName)"
    }
}

/// Inline editor for creating a new schedule block.
private struct BlockEditor: View {
    let onAdd: (ScheduleBlock) -> Void
    let onCancel: () -> Void

    @State private var label = ""
    @State private var startTime = Calendar.current.date(
        bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var duration = 60
    @State private var recurrence: ScheduleBlock.Recurrence = .daily

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Label (e.g. Lunch break)", text: $label)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            HStack {
                Text("Start").font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
                Spacer()
                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.stepperField)
                    .fixedSize()
            }

            HStack {
                Text("Duration").font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("\(duration) min").font(.system(size: 12)).foregroundStyle(.gray)
                Stepper("", value: $duration, in: 15...240, step: 15).labelsHidden()
            }

            Picker("", selection: $recurrence) {
                ForEach(ScheduleBlock.Recurrence.allCases) { r in
                    Text(r.displayName).tag(r)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
                Button("Add") {
                    let comps = Calendar.current.dateComponents([.hour, .minute], from: startTime)
                    let block = ScheduleBlock(
                        label: label.isEmpty ? "Block" : label,
                        startHour: comps.hour ?? 12,
                        startMinute: comps.minute ?? 0,
                        durationMinutes: duration,
                        recurrence: recurrence,
                        isEnabled: true
                    )
                    onAdd(block)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }
}
