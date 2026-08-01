//
//  LicenseManager.swift
//  Iris
//
//  Trial tracking and Gumroad license activation.
//
//  Setup: set gumroadPermalink to the short code from gumroad.com/l/<permalink>
//  once the Gumroad product exists. Leave it nil until then — the buy button
//  degrades gracefully and no broken URL is shown.
//

import Foundation

final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    private enum Keys {
        static let trialStart   = "iris.trialStart"
        static let licenseKey   = "iris.licenseKey"
        static let pendingKey   = "iris.licenseKeyPending"
    }

    // Set to your Gumroad permalink once the product is live.
    // nil means the buy button is hidden rather than broken.
    private static let gumroadPermalink: String? = nil

    static let trialDays = 7

    @Published private(set) var isLicensed: Bool
    @Published private(set) var isPendingVerification: Bool
    @Published private(set) var trialDaysRemaining: Int

    /// true if the engine should run
    var canRun: Bool { isLicensed || isPendingVerification || trialDaysRemaining > 0 }

    /// nil when Gumroad product is not yet configured
    var gumroadURL: URL? {
        guard let permalink = Self.gumroadPermalink else { return nil }
        return URL(string: "https://gumroad.com/l/\(permalink)")
    }

    private init() {
        if UserDefaults.standard.object(forKey: Keys.trialStart) == nil {
            UserDefaults.standard.set(Date(), forKey: Keys.trialStart)
        }
        isLicensed            = UserDefaults.standard.string(forKey: Keys.licenseKey) != nil
        isPendingVerification = UserDefaults.standard.string(forKey: Keys.pendingKey) != nil
        let start   = UserDefaults.standard.object(forKey: Keys.trialStart) as? Date ?? Date()
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? Self.trialDays
        trialDaysRemaining = max(0, Self.trialDays - elapsed)
    }

    enum ActivationResult {
        case success
        case invalid        // Gumroad explicitly rejected the key
        case networkError   // Gumroad unreachable; key provisionally accepted
    }

    func activate(key: String) async -> ActivationResult {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let permalink = Self.gumroadPermalink,
              let url = URL(string: "https://api.gumroad.com/v2/licenses/verify")
        else { return .invalid }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        request.httpBody = "product_id=\(permalink)&license_key=\(encoded)".data(using: .utf8)

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            // Network unreachable — accept the key provisionally.
            // The user who paid should never be locked out by Gumroad downtime.
            // verifyPendingKeyIfNeeded() is called on every subsequent launch to
            // confirm the key once connectivity is restored.
            await MainActor.run {
                UserDefaults.standard.set(trimmed, forKey: Keys.pendingKey)
                isPendingVerification = true
            }
            return .networkError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["success"] as? Bool == true
        else { return .invalid }

        await MainActor.run {
            UserDefaults.standard.set(trimmed, forKey: Keys.licenseKey)
            UserDefaults.standard.removeObject(forKey: Keys.pendingKey)
            isLicensed            = true
            isPendingVerification = false
        }
        return .success
    }

    /// Call once per launch (detached background Task) to confirm any key that
    /// was accepted offline. If Gumroad says the key is invalid, revokes access.
    /// A network error silently retains the provisional acceptance.
    func verifyPendingKeyIfNeeded() async {
        guard let pending = UserDefaults.standard.string(forKey: Keys.pendingKey) else { return }
        let result = await activate(key: pending)
        if result == .invalid {
            await MainActor.run {
                UserDefaults.standard.removeObject(forKey: Keys.pendingKey)
                isPendingVerification = false
            }
        }
        // .success clears pendingKey inside activate().
        // .networkError leaves pendingKey; user retains provisional access.
    }
}
