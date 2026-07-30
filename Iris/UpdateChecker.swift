//
//  UpdateChecker.swift
//  Iris
//
//  Wraps Sparkle 2's SPUStandardUpdaterController.
//  Automatic checks run on launch and daily (Sparkle's default schedule).
//  The "Check for Updates…" button in Settings triggers an immediate check.
//  isUpdateAvailable drives the banner in MainView; Sparkle's native sheet
//  handles the download, signature verification, and install.
//

import AppKit
import Sparkle

// MARK: - Delegate bridge (NSObject required by Sparkle's @objc protocol)

private final class SparkleDelegate: NSObject, SPUUpdaterDelegate {
    var onUpdateFound: (() -> Void)?
    var onNoUpdate: (() -> Void)?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        onUpdateFound?()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        onNoUpdate?()
    }
}

// MARK: - UpdateChecker

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published private(set) var isUpdateAvailable = false
    /// Kept for UI compatibility; Sparkle manages the install flow itself.
    @Published private(set) var isUpdating = false

    private let updaterController: SPUStandardUpdaterController
    private let delegate = SparkleDelegate()

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    private init() {
        let del = delegate
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: del,
            userDriverDelegate: nil
        )
        del.onUpdateFound = { [weak self] in
            Task { @MainActor in self?.isUpdateAvailable = true }
        }
        del.onNoUpdate = { [weak self] in
            Task { @MainActor in self?.isUpdateAvailable = false }
        }
    }

    func start() {
        try? updaterController.updater.start()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    // Legacy shim — Sparkle shows its own install sheet.
    func performUpdate() async {
        checkForUpdates()
    }
}
