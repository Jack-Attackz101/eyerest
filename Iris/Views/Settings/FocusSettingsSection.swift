//
//  FocusSettingsSection.swift
//  Iris
//
//  Settings UI for the Focus Blocker feature. Master toggle, block list with
//  per-item enable/disable and delete, "Add app" sheet, "Add website" inline
//  field, and AX permission warning when website items exist without access.
//

import SwiftUI
import AppKit

struct FocusSettingsSection: View {
    @ObservedObject var engine: TimerEngine

    @State private var showAddAppSheet = false
    @State private var newWebsite = ""
    @State private var showAXWarning = !AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            hero

            if engine.focusBlockerEnabled {
                SettingsCard {
                    blocklist
                    addRow
                    if showAXWarning && hasWebsites {
                        axWarningRow
                    }
                }
            }
        }
    }

    /// The blocker is the one thing no competitor has, and in the old panel it
    /// was a checkbox that looked exactly like "Sound cues". This is the only
    /// control in the app that gets its own card, its own state line and a count
    /// of what it is holding back.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.irisTintFocus.opacity(engine.focusBlockerEnabled ? 0.22 : 0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: engine.focusBlockerEnabled ? "shield.lefthalf.filled" : "shield")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.irisTintFocus)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Focus blocker")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(stateLine)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.irisTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: $engine.focusBlockerEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color.irisTintFocus)
                    .controlSize(.small)
            }
            .padding(14)

            if engine.focusBlockerEnabled && !engine.blockedItems.isEmpty {
                Text(previewLine)
                    .font(.system(size: 10))
                    .monospaced()
                    .foregroundStyle(Color.irisTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.irisCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(engine.focusBlockerEnabled
                        ? Color.irisTintFocus.opacity(0.45)
                        : Color.white.opacity(0.06),
                        lineWidth: 1)
        )
    }

    /// What it is doing right now, in words rather than a switch position.
    private var stateLine: String {
        guard engine.focusBlockerEnabled else {
            return "Off. Apps and sites you pick stay reachable."
        }
        let enabled = engine.blockedItems.filter(\.isEnabled).count
        guard enabled > 0 else { return "On, but nothing is on the list yet." }
        return "Blocking \(enabled) \(enabled == 1 ? "app or site" : "apps and sites") while you work."
    }

    /// The first few by name, so the list is legible without opening it.
    private var previewLine: String {
        let names = engine.blockedItems.filter(\.isEnabled).map(\.name)
        guard !names.isEmpty else { return "" }
        let shown = names.prefix(3).joined(separator: ", ")
        let extra = names.count - min(names.count, 3)
        return extra > 0 ? "\(shown) and \(extra) more" : shown
    }

    // MARK: - Subviews

    private var blocklist: some View {
        ForEach($engine.blockedItems) { $item in
            SettingRow {
                Image(systemName: item.kind == .app ? "app.badge" : "globe")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.irisSecondary)
                    .frame(width: 18)

                Text(item.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.irisSecondary)
                    .lineLimit(1)

                Spacer()

                Toggle("", isOn: $item.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color.irisAccent)
                    .controlSize(.mini)

                Button {
                    engine.blockedItems.removeAll { $0.id == item.id }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(Color.irisSecondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }
        }
    }

    private var addRow: some View {
        VStack(spacing: 0) {
            SettingRow {
                TextField("Add website (e.g. twitter.com)", text: $newWebsite)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .onSubmit { addWebsite() }

                if !newWebsite.isEmpty {
                    Button { addWebsite() } label: {
                        Image(systemName: "return")
                            .foregroundStyle(Color.irisAccent)
                    }
                    .buttonStyle(.plain)
                }
            }

            SettingRow {
                Button {
                    showAddAppSheet = true
                } label: {
                    Label("Add app", systemImage: "plus.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.irisAccent)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .sheet(isPresented: $showAddAppSheet) {
            AddAppSheet { name, bundleID in
                let item = BlockedItem.app(name: name, bundleID: bundleID)
                if !engine.blockedItems.contains(where: { $0.bundleID == bundleID }) {
                    engine.blockedItems.append(item)
                }
                requestAXIfNeeded()
            }
        }
    }

    private var axWarningRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11))
                .foregroundStyle(Color.yellow)

            Text("Enable Accessibility access to detect websites.")
                .font(.system(size: 11))
                .foregroundStyle(Color.irisSecondary)

            Spacer()

            Button("Allow") {
                AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary)
                showAXWarning = false
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(Color.irisAccent)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
    }

    // MARK: - Helpers

    private var hasWebsites: Bool {
        engine.blockedItems.contains { $0.kind == .website }
    }

    private func addWebsite() {
        let trimmed = newWebsite.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = BlockedItem.website(domain: trimmed)
        if !engine.blockedItems.contains(where: { $0.domain == item.domain }) {
            engine.blockedItems.append(item)
        }
        newWebsite = ""
        requestAXIfNeeded()
    }

    private func requestAXIfNeeded() {
        if !AXIsProcessTrusted() { showAXWarning = true }
    }
}

// MARK: - Add App Sheet

private struct AddAppSheet: View {
    let onAdd: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var apps: [AppEntry] = []
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add App")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button("Done") { dismiss() }
                    .foregroundStyle(Color.irisAccent)
            }
            .padding()

            TextField("Search apps", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider().overlay(Color.white.opacity(0.08))

            List(filtered, id: \.bundleID) { app in
                Button {
                    onAdd(app.name, app.bundleID)
                    dismiss()
                } label: {
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Text(app.name)
                            .font(.system(size: 13))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
        .frame(width: 340, height: 460)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { loadApps() }
    }

    private var filtered: [AppEntry] {
        if searchText.isEmpty { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func loadApps() {
        let urls = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
            + FileManager.default.urls(for: .applicationDirectory, in: .systemDomainMask)

        var seen = Set<String>()
        var entries: [AppEntry] = []

        for base in urls {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: base, includingPropertiesForKeys: nil
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let id = bundle.bundleIdentifier,
                      !seen.contains(id) else { continue }
                seen.insert(id)
                let name = bundle.infoDictionary?[kCFBundleNameKey as String] as? String
                    ?? url.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                entries.append(AppEntry(name: name, bundleID: id, icon: icon))
            }
        }

        apps = entries.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

private struct AppEntry {
    let name: String
    let bundleID: String
    let icon: NSImage?
}
