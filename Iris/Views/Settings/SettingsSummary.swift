//
//  SettingsSummary.swift
//  Iris
//
//  One line at the top of the Timer tab saying what Iris will actually do,
//  in the same words a person would use.
//
//  This is the single biggest thing missing from the old panel. Every row told
//  you what a setting was called; nothing told you what the app was going to do
//  with them, and there was no sense of whether Iris was running at all. The
//  sentence is assembled from the live settings, so it changes as they change
//  and it cannot drift out of date the way a written description would.
//

import SwiftUI

struct SettingsSummary: View {
    @ObservedObject var engine: TimerEngine

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            ZStack {
                Circle()
                    .fill(statusTint.opacity(0.16))
                    .frame(width: 26, height: 26)
                Circle()
                    .fill(statusTint)
                    .frame(width: 7, height: 7)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(statusHeadline)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusTint)
                Text(Self.sentence(for: engine))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(statusTint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(statusTint.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - State

    private var statusTint: Color {
        switch engine.popoverStatus {
        case .counting:    return .irisTintWellness
        case .callRunning: return .irisTintWellness
        default:           return .irisTintSystem
        }
    }

    private var statusHeadline: String {
        switch engine.popoverStatus {
        case .counting, .callRunning: return "RUNNING"
        case .userPaused:             return "PAUSED"
        case .callPaused:             return "PAUSED FOR A CALL"
        case .quietHours:             return "QUIET HOURS"
        case .scheduled:              return "SCHEDULED PAUSE"
        }
    }

    // MARK: - The sentence

    /// "a 20 second break every 20 minutes, paused during calls".
    ///
    /// The cycle, then at most two of the things that change when a break
    /// actually lands, in the order they matter. Everything is deliberately not
    /// listed: with six features on it stopped being a sentence and became a
    /// paragraph, which is the thing this replaced.
    static func sentence(for engine: TimerEngine) -> String {
        let core = "a \(engine.restDuration) second break every \(engine.intervalMinutes) minutes"

        var extras: [String] = []
        if engine.focusBlockerEnabled {
            let count = engine.blockedItems.filter(\.isEnabled).count
            if count > 0 {
                extras.append("\(count) \(count == 1 ? "app or site" : "apps and sites") blocked")
            }
        }
        if engine.autoPauseDuringCalls { extras.append("paused during calls") }
        if engine.quietHoursEnabled { extras.append("silent in quiet hours") }
        if engine.waitForNaturalGap { extras.append("never mid-sentence") }

        return ([core] + extras.prefix(2)).joined(separator: ", ")
    }
}
