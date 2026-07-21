//
//  CallDetector.swift
//  Iris
//
//  Detects an active video call so the timer can auto-pause (Feature 1). Polls
//  running applications every 30 seconds plus whether the camera is in use.
//

import AppKit
import AVFoundation
import ApplicationServices

final class CallDetector {

    /// Called on the main thread whenever the detected call state changes.
    var onChange: ((Bool) -> Void)?

    private var timer: Timer?
    private(set) var isInCall = false

    // Hard signals: these apps running means a call is very likely in progress.
    private let zoomBundleID = "us.zoom.xos"
    private let faceTimeBundleID = "com.apple.FaceTime"
    private let chromeBundleID = "com.google.Chrome"

    func start() {
        evaluate()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.evaluate()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Evaluation

    private func evaluate() {
        let running = NSWorkspace.shared.runningApplications
        let bundleIDs = Set(running.compactMap { $0.bundleIdentifier })

        let zoomRunning = bundleIDs.contains(zoomBundleID)
        let faceTimeRunning = bundleIDs.contains(faceTimeBundleID)
        let chromeRunning = bundleIDs.contains(chromeBundleID)

        // Chrome is only a *hard* signal if we can read a Google Meet tab title
        // through the Accessibility API; otherwise it's a soft signal we ignore
        // on its own.
        let chromeMeet = chromeRunning && chromeHasMeetWindow(in: running)

        let cameraInUse = isCameraInUse()

        let inCall = zoomRunning || faceTimeRunning || chromeMeet || cameraInUse

        if inCall != isInCall {
            isInCall = inCall
            let handler = onChange
            DispatchQueue.main.async { handler?(inCall) }
        }
    }

    /// Whether the default video camera is currently in use by any application.
    /// Reading this property is passive (no capture session, no prompt), but it
    /// still requires an `NSCameraUsageDescription` in Info.plist; without one,
    /// touching an `AVCaptureDevice` is a hard TCC crash. We also skip the query
    /// entirely when access has been explicitly denied/restricted.
    private func isCameraInUse() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            return false
        default:
            guard let device = AVCaptureDevice.default(for: .video) else { return false }
            return device.isInUseByAnotherApplication
        }
    }

    /// Best-effort check for a "Meet" window title in Chrome via Accessibility.
    /// Returns false (soft signal only) when Iris isn't a trusted AX client.
    private func chromeHasMeetWindow(in running: [NSRunningApplication]) -> Bool {
        guard AXIsProcessTrusted(),
              let chrome = running.first(where: { $0.bundleIdentifier == chromeBundleID })
        else { return false }

        let appElement = AXUIElementCreateApplication(chrome.processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return false }

        for window in windows {
            var titleValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
               let title = titleValue as? String,
               title.localizedCaseInsensitiveContains("meet") {
                return true
            }
        }
        return false
    }
}
