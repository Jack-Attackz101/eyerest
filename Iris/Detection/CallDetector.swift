//
//  CallDetector.swift
//  Iris
//
//  Detects an *active* call so the timer can auto-pause (Feature 1). It does NOT
//  flag apps merely for running in the background. A call is considered active
//  only when the camera is in use by another app, or when a known calling app
//  (Zoom / FaceTime) is the frontmost application. Polls every 30 seconds.
//

import AppKit
import AVFoundation

final class CallDetector {

    /// Called on the main thread whenever the detected call state changes.
    var onChange: ((Bool) -> Void)?

    private var timer: Timer?
    private(set) var isInCall = false

    private let zoomBundleID = "us.zoom.xos"
    private let faceTimeBundleID = "com.apple.FaceTime"

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
        // A known calling app being *frontmost* (not just running) is a call signal.
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let callAppFrontmost = frontmost == zoomBundleID || frontmost == faceTimeBundleID

        // The camera being in use by another app is the most reliable signal —
        // it also covers browser calls (Google Meet, etc.) without app checks.
        // Mic-in-use is deliberately NOT used: it could be music, dictation, etc.
        let inCall = isCameraInUse() || callAppFrontmost

        if inCall != isInCall {
            isInCall = inCall
            let handler = onChange
            DispatchQueue.main.async { handler?(inCall) }
        }
    }

    /// Whether the default video camera is currently in use by another app.
    /// Reading this property is passive (no capture session, no prompt), but it
    /// still requires `NSCameraUsageDescription`; we skip the query when access
    /// has been explicitly denied/restricted to avoid touching the device.
    private func isCameraInUse() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            return false
        default:
            guard let device = AVCaptureDevice.default(for: .video) else { return false }
            return device.isInUseByAnotherApplication
        }
    }
}
