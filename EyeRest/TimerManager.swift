import Foundation
import Combine
import AppKit
import ServiceManagement

@MainActor
final class TimerManager: ObservableObject {

    static let shared = TimerManager()

    private enum Keys {
        static let intervalMinutes = "eyerest.intervalMinutes"
        static let warningMinutes  = "eyerest.warningMinutes"
        static let restDuration    = "eyerest.restDuration"
        static let launchAtLogin   = "eyerest.launchAtLogin"
    }

    @Published var intervalMinutes: Int {
        didSet { UserDefaults.standard.set(intervalMinutes, forKey: Keys.intervalMinutes); resetCycle() }
    }
    @Published var warningMinutes: Int {
        didSet { UserDefaults.standard.set(warningMinutes, forKey: Keys.warningMinutes) }
    }
    @Published var restDurationSeconds: Int {
        didSet {
            let v = max(20, restDurationSeconds)
            if v != restDurationSeconds { restDurationSeconds = v; return }
            UserDefaults.standard.set(restDurationSeconds, forKey: Keys.restDuration)
        }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    @Published private(set) var timeUntilNextRest: TimeInterval = 0
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var isResting: Bool = false
    @Published private(set) var restSecondsRemaining: Int = 0
    @Published private(set) var warningVisible: Bool = false

    private var countdownTimer: Timer?
    private var restTimer: Timer?
    private var pausedTimeRemaining: TimeInterval = 0
    private var overlayController: OverlayWindowController?
    private var bannerController: WarningBannerWindowController?

    private init() {
        let ud = UserDefaults.standard
        intervalMinutes     = ud.object(forKey: Keys.intervalMinutes) as? Int ?? 20
        warningMinutes      = ud.object(forKey: Keys.warningMinutes)  as? Int ?? 2
        restDurationSeconds = ud.object(forKey: Keys.restDuration)    as? Int ?? 20
        launchAtLogin       = ud.object(forKey: Keys.launchAtLogin)   as? Bool ?? false
        timeUntilNextRest   = Double(intervalMinutes * 60)

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    func start()  { resetCycle() }
    func pause()  { guard !isPaused, !isResting else { return }; pausedTimeRemaining = timeUntilNextRest; stopCountdown(); dismissWarning(); isPaused = true }
    func resume() { guard isPaused else { return }; isPaused = false; startCountdown(from: pausedTimeRemaining) }
    func togglePause() { isPaused ? resume() : pause() }
    func skipCurrentRest() { guard isResting else { return }; endRest() }

    func resetCycle() {
        stopCountdown(); dismissWarning()
        timeUntilNextRest = Double(intervalMinutes * 60)
        isPaused = false
        startCountdown(from: timeUntilNextRest)
    }

    func triggerRestNow() { stopCountdown(); dismissWarning(); beginRest() }

    private func startCountdown(from seconds: TimeInterval) {
        timeUntilNextRest = seconds
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    private func stopCountdown() { countdownTimer?.invalidate(); countdownTimer = nil }

    private func tick() {
        guard !isPaused, !isResting else { return }
        timeUntilNextRest -= 1
        let warn = Double(warningMinutes * 60)
        if timeUntilNextRest <= 0 { timeUntilNextRest = 0; stopCountdown(); dismissWarning(); beginRest() }
        else if timeUntilNextRest <= warn, !warningVisible { showWarning() }
    }

    private func beginRest() {
        isResting = true; restSecondsRemaining = restDurationSeconds
        showOverlay()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.restTick() }
        }
        RunLoop.main.add(restTimer!, forMode: .common)
    }

    private func restTick() { restSecondsRemaining -= 1; if restSecondsRemaining <= 0 { endRest() } }

    private func endRest() { restTimer?.invalidate(); restTimer = nil; isResting = false; hideOverlay(); resetCycle() }

    private func showOverlay()   { overlayController = OverlayWindowController(); overlayController?.showOverlay() }
    private func hideOverlay()   { overlayController?.hideOverlay(); overlayController = nil }
    private func showWarning()   { warningVisible = true; bannerController = WarningBannerWindowController(); bannerController?.showBanner() }
    private func dismissWarning() { guard warningVisible else { return }; warningVisible = false; bannerController?.hideBanner(); bannerController = nil }

    @objc private func handleWake() { guard !isResting else { return }; resetCycle() }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        }
    }
}
