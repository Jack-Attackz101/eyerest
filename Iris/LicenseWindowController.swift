//
//  LicenseWindowController.swift
//  Iris
//
//  Shown at launch when the trial has expired and no license key is stored.
//  Presents a "Buy" button and a license key entry field.
//

import AppKit
import SwiftUI

@MainActor
final class LicenseWindowController: NSObject {
    private var panel: NSPanel?
    var onActivated: (() -> Void)?

    func show() {
        let content = LicenseActivationView { [weak self] in
            self?.close()
            self?.onActivated?()
        }
        let host = NSHostingController(rootView: content)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 1),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Iris"
        panel.contentViewController = host
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    private func close() {
        panel?.close()
        panel = nil
    }
}

private struct LicenseActivationView: View {
    @ObservedObject private var license = LicenseManager.shared
    @State private var key = ""
    @State private var isActivating = false
    @State private var failed = false

    let onActivated: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Your Iris trial has ended")
                    .font(.system(size: 17, weight: .semibold))
                Text("Purchase a license to continue using Iris.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                NSWorkspace.shared.open(LicenseManager.shared.gumroadURL)
            } label: {
                Text("Buy - $35")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Already purchased? Enter your license key.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("License key", text: $key)
                        .textFieldStyle(.roundedBorder)
                    Button(isActivating ? "Checking..." : "Activate") {
                        Task { await tryActivate() }
                    }
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || isActivating)
                }
                if failed {
                    Text("Key not recognised. Check for typos or contact support.")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(28)
        .frame(width: 380)
    }

    private func tryActivate() async {
        isActivating = true
        failed = false
        let ok = await LicenseManager.shared.activate(key: key)
        isActivating = false
        if ok { onActivated() } else { failed = true }
    }
}
