//
//  HotkeyRecorderRow.swift
//  Iris
//
//  The shortcut field. Click it, press a combination, and it takes. Escape
//  cancels and leaves the old one alone.
//
//  It says out loud when a combination will not work, because the failure mode
//  of a global shortcut is silence: you press it, nothing happens, and there is
//  nothing on screen to explain why.
//

import SwiftUI
import AppKit

struct HotkeyRecorderRow: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject private var status = HotkeyStatus.shared

    /// Re-registers after a change. AppDelegate owns registration, so the row
    /// asks rather than doing it.
    let onChange: () -> Void

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingRow {
                RowIcon(systemName: "command", tint: .irisTintSystem)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Start a break")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(recording ? "Press a combination, or Escape to cancel"
                                   : "Works anywhere, even when Iris is not in front")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.irisTertiary)
                }
                Spacer(minLength: 8)
                Button(recording ? "Listening" : engine.breakHotkey.displayString) {
                    recording ? stopRecording() : startRecording()
                }
                .font(.system(size: 12, weight: .medium))
                .monospaced()
                .foregroundStyle(recording ? Color.irisAccent : .white.opacity(0.92))
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(recording ? 0.45 : 0.28))
                )
            }

            if let failure = status.failure {
                Text(failure.message)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: 0xD1603F))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    // MARK: - Recording

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            guard event.type == .keyDown else { return event }
            if event.keyCode == 53 {          // Escape, leave the old one alone
                stopRecording()
                return nil
            }
            let combo = HotkeyCombo(
                keyCode: UInt32(event.keyCode),
                modifierFlags: event.modifierFlags
                    .intersection([.command, .option, .control, .shift]).rawValue
            )
            stopRecording()
            guard combo.isUsable else {
                status.failure = .needsAModifier
                return nil
            }
            engine.breakHotkey = combo
            onChange()
            return nil                        // swallow it, do not type a letter
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
