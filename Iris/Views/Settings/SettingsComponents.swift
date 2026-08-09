//
//  SettingsComponents.swift
//  Iris
//
//  Building blocks for the settings panel.
//
//  The panel used to be one long scroll of eight sections in a 380pt window,
//  rendered in greyscale with text-only rows. Two things were wrong with that:
//  you could not find anything without scrolling past everything, and every row
//  looked identical so nothing was scannable.
//
//  This file adds three things and keeps every existing call site working:
//    - a card container, so related settings read as a group
//    - an optional leading icon on rows, tinted per category
//    - a tab bar, so the panel shows one topic at a time instead of all eight
//

import SwiftUI

// MARK: - Category tints
//
// Pulled from the Iris brand palette used on the site so the app and the
// landing page look like the same product. Green and terracotta are lifted a
// little from their paper values because the originals are too dark to read
// against #0D0D0D.

extension Color {
    static let irisTintTimer    = Color(hex: 0x4B6BFB)   // accent blue
    static let irisTintSound    = Color(hex: 0x5B9AB8)   // brand blue
    static let irisTintSchedule = Color(hex: 0x7C6BFB)   // indigo
    static let irisTintFocus    = Color(hex: 0xD1603F)   // brand terracotta, lifted
    static let irisTintWellness = Color(hex: 0x5E9B47)   // brand green, lifted
    static let irisTintSystem   = Color(hex: 0x8A8A8A)   // neutral
    static let irisDivider      = Color.white.opacity(0.055)
}

// MARK: - Section header

/// Uppercase section label. Kept for the section files that already use it.
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.9)
            .foregroundStyle(Color.irisSectionLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
    }
}

// MARK: - Card

/// Groups related rows into a single raised surface. Rows draw their own
/// bottom divider, so the card clips the last one flush against its edge.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.irisCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Row icon

/// Fixed-width leading glyph so every label in a card starts at the same x,
/// which is what makes a list scannable rather than ragged.
struct RowIcon: View {
    let systemName: String
    var tint: Color = .irisAccent

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
    }
}

// MARK: - Rows

/// A 44pt row with a hairline underneath. Signature unchanged.
struct SettingRow<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { content }
                .frame(height: 44)
                .padding(.horizontal, 12)
            Rectangle()
                .fill(Color.irisDivider)
                .frame(height: 1)
        }
    }
}

/// Label plus a switch, with an optional leading icon.
struct SettingToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    var icon: String? = nil
    var tint: Color = .irisAccent
    var caption: String? = nil

    var body: some View {
        SettingRow {
            if let icon = icon { RowIcon(systemName: icon, tint: tint) }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.92))
                if let caption = caption {
                    Text(caption)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.irisTertiary)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(tint)
                .controlSize(.small)
        }
    }
}

/// Label, value, and a stepper. The value pops briefly on change so a click
/// always produces visible feedback.
struct SettingStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let display: String
    var icon: String? = nil
    var tint: Color = .irisAccent

    @State private var pop: CGFloat = 1.0

    var body: some View {
        SettingRow {
            if let icon = icon { RowIcon(systemName: icon, tint: tint) }
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.92))
            Spacer(minLength: 8)
            Text(display)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(tint)
                .scaleEffect(pop)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
                .onChange(of: value) { _ in
                    pop = 1.12
                    withAnimation(.easeOut(duration: 0.18)) { pop = 1.0 }
                }
        }
    }
}

// MARK: - Tab bar

/// The four groups the settings panel is split into.
enum SettingsTab: String, CaseIterable, Identifiable {
    case timer, focus, wellness, system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .timer:    return "Timer"
        case .focus:    return "Focus"
        case .wellness: return "Body"
        case .system:   return "App"
        }
    }

    var icon: String {
        switch self {
        case .timer:    return "timer"
        case .focus:    return "moon.fill"
        case .wellness: return "figure.walk"
        case .system:   return "gearshape.fill"
        }
    }

    var tint: Color {
        switch self {
        case .timer:    return .irisTintTimer
        case .focus:    return .irisTintFocus
        case .wellness: return .irisTintWellness
        case .system:   return .irisTintSystem
        }
    }
}

/// Segmented switcher. The selected pill is tinted with the tab's own colour so
/// the panel tells you where you are without reading the label.
struct SettingsTabBar: View {
    @Binding var selection: SettingsTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                let active = tab == selection
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.label)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(active ? tab.tint : Color.irisTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background {
                        if active {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(tab.tint.opacity(0.14))
                                .matchedGeometryEffect(id: "tabpill", in: ns)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.28))
        )
    }
}
