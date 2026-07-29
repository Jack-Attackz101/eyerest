//
//  PostureCameraEngine.swift
//  Iris
//
//  Periodically captures a camera frame and uses Vision to detect if the user
//  is leaning forward (face significantly lower than calibrated baseline).
//
//  Permission behaviour:
//    - Always OFF by default.
//    - Settings shows an explanation before the toggle is visible.
//    - If Camera is denied after the user enables the toggle, the toggle is
//      reset to OFF and a notice is shown in Settings.
//

import Foundation
@preconcurrency import AVFoundation
import Vision
import AppKit

@MainActor
final class PostureCameraEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    static let shared = PostureCameraEngine()

    private let engine = TimerEngine.shared

    /// Called on the main thread when a lean-forward is detected.
    var onPostureAlert: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private var outputQueue = DispatchQueue(label: "iris.posture.camera", qos: .utility)
    private var isRunning = false

    // Baseline: average normalised face-centre Y over first calibration frames.
    private var baselineSamples: [Double] = []
    private var baselineY: Double? = nil
    private let calibrationCount = 20
    private let leanThreshold = 0.12   // fraction of frame height

    // Rate limiting: don't alert more than once per 5 minutes.
    private var lastAlertDate: Date? = nil
    private let alertCooldown: TimeInterval = 5 * 60

    // Sample every 30 seconds when running.
    private var sampleTimer: Timer?

    private override init() { super.init() }

    // MARK: - Lifecycle

    func start() {
        guard engine.postureCameraEnabled else { return }
        requestCameraAndBegin()
    }

    func stop() {
        sampleTimer?.invalidate(); sampleTimer = nil
        captureSession?.stopRunning()
        captureSession = nil
        isRunning = false
        baselineSamples = []
        baselineY = nil
    }

    func restart() {
        stop()
        start()
    }

    // MARK: - Permission

    func requestCameraAndBegin() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            beginCapture()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.beginCapture()
                    } else {
                        // User denied — turn the setting back off.
                        self?.engine.postureCameraEnabled = false
                    }
                }
            }
        default:
            // Already denied/restricted — turn setting off.
            engine.postureCameraEnabled = false
        }
    }

    // MARK: - Capture setup

    private func beginCapture() {
        guard !isRunning else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            let session = AVCaptureSession()
            session.sessionPreset = .low
            guard session.canAddInput(input) else { return }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:
                                        kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: outputQueue)
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)

            captureSession = session
            isRunning = true

            // Sample every 30 seconds via timer; grab one frame per sample.
            let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.triggerSample() }
            }
            RunLoop.main.add(t, forMode: .common)
            sampleTimer = t
            // Capture first frame immediately after short delay.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                Task { @MainActor [weak self] in self?.triggerSample() }
            }

            let captureSession = session
            Task.detached { captureSession.startRunning() }
        } catch {
            NSLog("Iris: PostureCameraEngine setup failed: \(error.localizedDescription)")
        }
    }

    private var wantNextFrame = false

    private func triggerSample() {
        guard engine.postureCameraEnabled else { stop(); return }
        wantNextFrame = true
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        Task { @MainActor in
            guard self.wantNextFrame else { return }
            self.wantNextFrame = false
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            self.analyseFrame(pixelBuffer)
        }
    }

    // MARK: - Vision analysis

    private func analyseFrame(_ pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceRectanglesRequest { [weak self] req, _ in
            guard let self,
                  let obs = req.results as? [VNFaceObservation],
                  let face = obs.first else { return }
            // boundingBox is normalised (0–1), origin at bottom-left.
            // midY increases upward in Vision coords.
            let midY = face.boundingBox.midY
            self.processFaceMidY(midY)
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func processFaceMidY(_ midY: Double) {
        if baselineY == nil {
            baselineSamples.append(midY)
            if baselineSamples.count >= calibrationCount {
                baselineY = baselineSamples.reduce(0, +) / Double(baselineSamples.count)
                baselineSamples = []
            }
            return
        }

        guard let baseline = baselineY else { return }
        // User leaning forward → face appears lower in frame → midY decreases.
        let drop = baseline - midY
        guard drop > leanThreshold else { return }

        // Rate-limit alerts.
        let now = Date()
        if let last = lastAlertDate, now.timeIntervalSince(last) < alertCooldown { return }
        lastAlertDate = now
        onPostureAlert?()
    }
}
