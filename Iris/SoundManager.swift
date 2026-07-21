//
//  SoundManager.swift
//  Iris
//
//  Loads the three bundled .aiff cues and plays them with NSSound, which
//  already respects the system output volume (a muted machine stays silent).
//  If a bundled file is missing it falls back to a comparable system sound.
//

import AppKit

final class SoundManager {

    enum Cue {
        case warning     // Warning pill appears.
        case restStart   // Blackout begins.
        case restEnd     // Screen fades back.
    }

    private var sounds: [String: NSSound] = [:]

    init() {
        preload("warning", fallbackSystemName: "Tink")
        preload("rest-start", fallbackSystemName: "Submarine")
        preload("rest-end", fallbackSystemName: "Glass")
    }

    func play(_ cue: Cue, enabled: Bool) {
        guard enabled else { return }
        let sound = sounds[key(for: cue)]
        sound?.stop()
        sound?.currentTime = 0
        sound?.play()
    }

    // MARK: - Private

    private func key(for cue: Cue) -> String {
        switch cue {
        case .warning: return "warning"
        case .restStart: return "rest-start"
        case .restEnd: return "rest-end"
        }
    }

    private func preload(_ name: String, fallbackSystemName: String) {
        if let url = Bundle.main.url(forResource: name, withExtension: "aiff"),
           let sound = NSSound(contentsOf: url, byReference: true) {
            sounds[name] = sound
        } else if let system = NSSound(named: fallbackSystemName) {
            sounds[name] = system
        }
    }
}
