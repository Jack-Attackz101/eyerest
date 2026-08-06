//
//  LicenseWindowController.swift
//  Iris
//
//  Shown at launch when the trial has expired and no license key is stored.
//  Presents a "Buy" button and a license key entry field.
//

import AppKit
import SwiftUI

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
    @State private var networkError = false

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

            if let url = LicenseManager.shared.gumroadURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Text("Buy - $14")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            } else {
                Text("buy link coming soon · $14")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

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
                if networkError {
                    Text("Could not reach Gumroad. Your key has been accepted for now and will be verified next time you launch Iris online.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(28)
        .frame(width: 380)
    }

    private func tryActivate() async {
        isActivating = true
        failed = false
        networkError = false
        let result = await LicenseManager.shared.activate(key: key)
        isActivating = false
        switch result {
        case .success, .networkError:
            onActivated()
        case .invalid:
            failed = true
        }
    }
}
