//
//  AmbientPlayer.swift
//  Iris
//
//  Soft looping ambient tone played during the rest blackout (Feature 3).
//  Fades in on start and out on stop.
//

import AVFoundation

final class AmbientPlayer {

    private var player: AVAudioPlayer?
    private let targetVolume: Float = 0.4
    private let fadeDuration: TimeInterval = 0.5

    init() {
        guard let url = Bundle.main.url(forResource: "ambient", withExtension: "aiff") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1   // loop forever
        player?.volume = 0
        player?.prepareToPlay()
    }

    /// Begin the loop, fading volume 0 → 0.4 over 0.5s.
    func start() {
        guard let player else { return }
        player.currentTime = 0
        player.volume = 0
        player.play()
        player.setVolume(targetVolume, fadeDuration: fadeDuration)
    }

    /// Fade out over 0.5s, then stop.
    func stop() {
        guard let player, player.isPlaying else { return }
        player.setVolume(0, fadeDuration: fadeDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) { [weak player] in
            player?.stop()
        }
    }
}
