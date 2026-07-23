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
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Focus Blocker")

            SettingToggleRow(label: "Block distracting apps & sites", isOn: $engine.focusBlockerEnabled)

            if engine.focusBlockerEnabled {
                blocklist
                addRow
                if showAXWarning && hasWebsites {
                    axWarningRow
                }
            }
        }
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
