//
//  DemoSettingsSection.swift
//  Iris
//
//  Debug-only. Instantly triggers any of the 12 new features so you can
//  record demo clips without waiting for timers to fire.
//  This entire file is excluded from Release builds via the #if DEBUG guard.
//

#if DEBUG
import SwiftUI

struct DemoSettingsSection: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject private var budget = NudgeBudget.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Demo / Testing")

            Text("Debug builds only")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.irisAccent.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // Feature 1, Micro-stretch card
            // Enables stretch cards for this session and starts a rest.
            // The stretch card shows for 15 s, then the countdown runs.
            DemoRow("Micro-stretch card") {
                engine.stretchCardsEnabled = true
                engine.restNow()
            }

            // Morning movement challenge (bypasses the once-per-day date gate)
            DemoRow("Morning challenge") {
                NotificationCenter.default.post(name: .irisDemoChallenge, object: nil)
            }

            // Feature 12, Posture nudge (camera-based)
            DemoRow("Posture nudge") {
                NotificationCenter.default.post(name: .irisDemoNudge, object: "sit up straight")
            }

            // Feature 2, Water reminder
            DemoRow("Water reminder") {
                NotificationCenter.default.post(name: .irisDemoNudge, object: "drink some water")
            }

            // Feature 4, Stand-up mode
            DemoRow("Stand-up nudge") {
                NotificationCenter.default.post(name: .irisDemoNudge, object: "time to stand up")
            }

            // Feature 5, Late-night guard wrap-up
            DemoRow("Late-night wrap-up") {
                NotificationCenter.default.post(name: .irisDemoNudge, object: "time to wrap up")
            }

            // Feature 6, Brightness check
            DemoRow("Brightness nudge") {
                NotificationCenter.default.post(name: .irisDemoNudge, object: "lower your brightness")
            }

            // Feature 7, End-of-day wind-down
            DemoRow("Wind-down overlay") {
                NotificationCenter.default.post(name: .irisWindDownRequested, object: nil)
            }

            // Feature 8, Desk reset checklist
            DemoRow("Desk reset checklist") {
                NotificationCenter.default.post(name: .irisDeskResetRequested, object: nil)
            }

            // Feature 9, Wrist relief timer
            DemoRow("Wrist relief nudge") {
                NotificationCenter.default.post(name: .irisDemoNudge, object: "shake out your wrists")
            }

            // Feature 10, Post-meeting reset
            DemoRow("Post-meeting reset") {
                NotificationCenter.default.post(name: .irisDemoNudge, object: "look away, 20 sec")
            }

            // Feature 11, Scroll fatigue
            DemoRow("Scroll fatigue nudge") {
                NotificationCenter.default.post(name: .irisDemoNudge, object: "rest your wrists")
            }

            nudgeBudget
        }
    }

    // MARK: - Nudge budget
    //
    // The rows above bypass the gate on purpose. These two go through it, so it
    // is possible to see the budget accept, merge and refuse in real use rather
    // than reasoning about it. The counters answer the only question that
    // matters after shipping: is 8 minutes and 4 an hour too tight?

    private var nudgeBudget: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Nudge budget")
                .padding(.top, 14)

            SettingsCard {
                DemoRow("Request water via budget") {
                    NudgeBudget.shared.request(.water) { text in
                        NotificationCenter.default.post(name: .irisDemoNudge, object: text)
                    }
                }

                // Two requests inside the coalescing window must produce one
                // combined pill, not two in a row.
                DemoRow("Request stand up + wrists (coalesce)") {
                    NudgeBudget.shared.request(.standUp) { text in
                        NotificationCenter.default.post(name: .irisDemoNudge, object: text)
                    }
                    NudgeBudget.shared.request(.wristRelief) { text in
                        NotificationCenter.default.post(name: .irisDemoNudge, object: text)
                    }
                }

                SettingRow {
                    Text("This hour")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.irisSecondary)
                    Spacer()
                    Text("\(budget.shownInLastHour) of \(NudgeBudget.nudgesPerHourCap) shown, "
                         + "gap clears in \(budget.secondsUntilGapClears)s")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.irisTertiary)
                }

                ForEach(NudgeBudget.Source.allCases) { source in
                    let tally = budget.tallies[source] ?? NudgeBudget.Tally()
                    SettingRow {
                        Text(source.label)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.irisSecondary)
                        Spacer()
                        Text(Self.tallyText(tally))
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(Color.irisTertiary)
                    }
                }

                SettingRow {
                    Spacer()
                    Button("Reset counters") { budget.resetTallies() }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.irisAccent)
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private static func tallyText(_ tally: NudgeBudget.Tally) -> String {
        var text = "\(tally.granted) granted, \(tally.denied) denied"
        if let reason = tally.lastDenial { text += " (\(reason.rawValue))" }
        return text
    }
}

// MARK: - Row

private struct DemoRow: View {
    let label: String
    let action: () -> Void

    init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        SettingRow {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.irisSecondary)
            Spacer()
            Button("Trigger") { action() }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.irisAccent)
                .buttonStyle(.plain)
        }
    }
}
#endif
