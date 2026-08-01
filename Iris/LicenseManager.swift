//
//  LicenseManager.swift
//  Iris
//
//  Trial tracking and Gumroad license activation.
//  License key is stored in UserDefaults after successful activation.
//  Verification calls Gumroad once (at activation time) and caches the result.
//
//  To finish setup: replace REPLACE_WITH_PERMALINK below with your Gumroad
//  product permalink (the short code from gumroad.com/l/<permalink>).
//

import Foundation

final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    private enum Keys {
        static let trialStart  = "iris.trialStart"
        static let licenseKey  = "iris.licenseKey"
    }

    static let gumroadPermalink = "REPLACE_WITH_PERMALINK"
    static let trialDays = 7

    @Published private(set) var isLicensed: Bool
    @Published private(set) var trialDaysRemaining: Int

    var canRun: Bool { isLicensed || trialDaysRemaining > 0 }

    var gumroadURL: URL {
        URL(string: "https://gumroad.com/l/\(Self.gumroadPermalink)")!
    }

    private init() {
        if UserDefaults.standard.object(forKey: Keys.trialStart) == nil {
            UserDefaults.standard.set(Date(), forKey: Keys.trialStart)
        }
        isLicensed = UserDefaults.standard.string(forKey: Keys.licenseKey) != nil
        let start   = UserDefaults.standard.object(forKey: Keys.trialStart) as? Date ?? Date()
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? Self.trialDays
        trialDaysRemaining = max(0, Self.trialDays - elapsed)
    }

    func activate(key: String) async -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let url = URL(string: "https://api.gumroad.com/v2/licenses/verify")
        else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        request.httpBody = "product_id=\(Self.gumroadPermalink)&license_key=\(encoded)".data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["success"] as? Bool == true
        else { return false }

        await MainActor.run {
            UserDefaults.standard.set(trimmed, forKey: Keys.licenseKey)
            isLicensed = true
        }
        return true
    }
}
