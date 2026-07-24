//
//  UpdateChecker.swift
//  Iris
//
//  Polls useiris.vercel.app/latest-version.txt on launch and every 4 hours.
//  When a newer version is available, exposes isUpdateAvailable = true.
//  performUpdate() downloads the DMG, verifies its signature, installs, and
//  relaunches from /Applications/Iris.app.
//

import AppKit
import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    private init() {}

    @Published private(set) var isUpdateAvailable = false
    @Published private(set) var isUpdating        = false

    private let versionURL = URL(string: "https://useiris.vercel.app/latest-version.txt")!
    private let dmgURL     = URL(string: "https://useiris.vercel.app/Iris.dmg")!
    private let localDMG   = URL(fileURLWithPath: "/tmp/Iris.dmg")

    private var checkTimer: Timer?

    // MARK: - Start

    func start() {
        Task { await checkForUpdate() }
        checkTimer = Timer.scheduledTimer(withTimeInterval: 4 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.checkForUpdate() }
        }
    }

    // MARK: - Version check

    private func checkForUpdate() async {
        guard
            let (data, _) = try? await URLSession.shared.data(from: versionURL),
            let remote    = String(data: data, encoding: .utf8)?
                                .trimmingCharacters(in: .whitespacesAndNewlines),
            let current   = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        else { return }
        isUpdateAvailable = isNewer(remote, than: current)
    }

    /// Returns true when `a` is semantically greater than `b`.
    private func isNewer(_ a: String, than b: String) -> Bool {
        let lhs = a.split(separator: ".").compactMap { Int($0) }
        let rhs = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    // MARK: - Perform update

    func performUpdate() async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        // 1. Download DMG
        do {
            let (tmpURL, _) = try await URLSession.shared.download(from: dmgURL)
            try? FileManager.default.removeItem(at: localDMG)
            try FileManager.default.moveItem(at: tmpURL, to: localDMG)
        } catch {
            await failAlert(); return
        }

        // 2. Mount
        guard await shell("/usr/bin/hdiutil", ["attach", localDMG.path, "-nobrowse", "-quiet"]) == 0 else {
            cleanup(); await failAlert(); return
        }

        // 3. Locate Iris.app on the mounted volume
        guard let mountPoint = mountedVolume(containing: "Iris.app") else {
            cleanup(); await failAlert(); return
        }
        let srcApp  = URL(fileURLWithPath: mountPoint).appendingPathComponent("Iris.app")
        let destApp = URL(fileURLWithPath: "/Applications/Iris.app")

        // 4. Verify code signature
        guard await shell("/usr/bin/codesign", ["--verify", "--deep", srcApp.path]) == 0 else {
            _ = await shell("/usr/bin/hdiutil", ["detach", mountPoint, "-quiet"])
            cleanup(); await failAlert(); return
        }

        // 5. Install to /Applications
        do {
            if FileManager.default.fileExists(atPath: destApp.path) {
                try FileManager.default.removeItem(at: destApp)
            }
            try FileManager.default.copyItem(at: srcApp, to: destApp)
        } catch {
            _ = await shell("/usr/bin/hdiutil", ["detach", mountPoint, "-quiet"])
            cleanup(); await failAlert(); return
        }

        // 6. Detach DMG and remove /tmp copy
        _ = await shell("/usr/bin/hdiutil", ["detach", mountPoint, "-quiet"])
        cleanup()

        // 7. Relaunch and quit
        let launcher = Process()
        launcher.launchPath = "/usr/bin/open"
        launcher.arguments  = ["-n", destApp.path]
        try? launcher.run()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Private helpers

    private func mountedVolume(containing appName: String) -> String? {
        guard let vols = try? FileManager.default.contentsOfDirectory(atPath: "/Volumes") else { return nil }
        return vols
            .map { "/Volumes/\($0)" }
            .first { FileManager.default.fileExists(atPath: "\($0)/\(appName)") }
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: localDMG)
    }

    @discardableResult
    private func shell(_ path: String, _ args: [String]) async -> Int32 {
        await withCheckedContinuation { cont in
            let proc = Process()
            proc.launchPath  = path
            proc.arguments   = args
            proc.standardOutput = Pipe()
            proc.standardError  = Pipe()
            proc.terminationHandler = { p in cont.resume(returning: p.terminationStatus) }
            try? proc.run()
        }
    }

    private func failAlert() async {
        let alert = NSAlert()
        alert.messageText     = "Update Failed"
        alert.informativeText = "Update failed. Please download the latest version from useiris.vercel.app."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
