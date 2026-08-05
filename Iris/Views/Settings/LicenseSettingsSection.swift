//
//  LicenseSettingsSection.swift
//  Iris
//

import SwiftUI

struct LicenseSettingsSection: View {
    @ObservedObject private var license = LicenseManager.shared
    @State private var key = ""
    @State private var isActivating = false
    @State private var failed = false
    @State private var succeeded = false
    @State private var networkError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "License")
            if license.isLicensed {
                SettingRow {
                    Text("Licensed")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.irisAccent)
                }
            } else if license.isPendingVerification {
                SettingRow {
                    Text("Pending verification")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                }
            } else {
                SettingRow {
                    if license.trialDaysRemaining > 0 {
                        Text("\(license.trialDaysRemaining) day\(license.trialDaysRemaining == 1 ? "" : "s") left in trial")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Trial ended")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: 0xCC4444))
                    }
                    Spacer()
                    if let url = LicenseManager.shared.gumroadURL {
                        Button("Buy - $14") {
                            NSWorkspace.shared.open(url)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.irisAccent)
                        .buttonStyle(.plain)
                    } else {
                        Text("buy link coming soon")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                SettingRow {
                    TextField("License key", text: $key)
                        .font(.system(size: 12))
                        .textFieldStyle(.roundedBorder)
                    Button(isActivating ? "..." : "Activate") {
                        Task { await tryActivate() }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.irisAccent)
                    .buttonStyle(.plain)
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || isActivating)
                }
                if failed {
                    SettingRow {
                        Text("Key not recognised.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: 0xCC4444))
                    }
                }
                if networkError {
                    SettingRow {
                        Text("No internet. Key accepted offline — will verify next launch.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                if succeeded {
                    SettingRow {
                        Text("Activated. Thank you.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.irisAccent)
                    }
                }
            }
        }
    }

    private func tryActivate() async {
        isActivating = true
        failed = false
        succeeded = false
        networkError = false
        let result = await LicenseManager.shared.activate(key: key)
        isActivating = false
        switch result {
        case .success:    succeeded = true
        case .invalid:    failed = true
        case .networkError: networkError = true
        }
    }
}
