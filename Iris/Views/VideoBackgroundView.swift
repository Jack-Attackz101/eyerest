//
//  VideoBackgroundView.swift
//  Iris
//
//  A looping, muted AVPlayer video background bridged into SwiftUI. The player
//  is torn down when the popover closes so nothing leaks between sessions.
//

import AVFoundation
import SwiftUI

struct VideoBackgroundView: NSViewRepresentable {
    @ObservedObject var state: DashboardState

    func makeNSView(context: Context) -> LoopingVideoView {
        LoopingVideoView()
    }

    func updateNSView(_ view: LoopingVideoView, context: Context) {
        view.apply(environment: state.environment,
                   isOpen: state.isOpen,
                   playing: state.shouldPlay,
                   session: state.sessionID)
    }

    static func dismantleNSView(_ view: LoopingVideoView, coordinator: ()) {
        view.teardown()
    }
}

/// Layer-hosting NSView that owns the AVPlayer + looper for one environment.
final class LoopingVideoView: NSView {

    private let playerLayer = AVPlayerLayer()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentEnvironment: DashboardState.Environment?
    private var currentSession = -1

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    func apply(environment: DashboardState.Environment, isOpen: Bool, playing: Bool, session: Int) {
        guard isOpen else { teardown(); return }

        if environment != currentEnvironment || session != currentSession || player == nil {
            load(environment)
            currentEnvironment = environment
            currentSession = session
        }

        if playing { player?.play() } else { player?.pause() }
    }

    private func load(_ environment: DashboardState.Environment) {
        teardown()
        guard let url = Bundle.main.url(forResource: environment.videoName, withExtension: "mp4") else { return }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.actionAtItemEnd = .none
        looper = AVPlayerLooper(player: queue, templateItem: item)   // seamless, gapless loop
        playerLayer.player = queue
        player = queue
        queue.play()
    }

    func teardown() {
        player?.pause()
        playerLayer.player = nil
        looper = nil
        player = nil
        currentEnvironment = nil
        currentSession = -1
    }
}
