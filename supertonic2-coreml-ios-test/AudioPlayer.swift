//
//  AudioPlayer.swift
//  supertonic2-coreml-ios-test
//
//  Created by Codex.
//

import Foundation
import AVFoundation

final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var onFinish: (() -> Void)?
    private var progressTimer: Timer?

    /// Called periodically with (currentTime, duration) during playback.
    var onProgress: ((TimeInterval, TimeInterval) -> Void)?

    /// Duration of the currently loaded audio file.
    var duration: TimeInterval { player?.duration ?? 0 }

    /// Current playback position.
    var currentTime: TimeInterval { player?.currentTime ?? 0 }

    /// Whether the player is actively playing (not paused).
    var isPlaying: Bool { player?.isPlaying ?? false }

    func play(url: URL, onFinish: (() -> Void)? = nil) {
        self.onFinish = onFinish
        stopProgressTimer()
        do {
            let session = AVAudioSession.sharedInstance()
            // Use `.playback` (no `.mixWithOthers`) so background audio is
            // properly declared and the app can continue while screen is locked.
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let data = try Data(contentsOf: url)
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            self.player = player
            startProgressTimer()
        } catch {
            print("Audio play error: \(error)")
            onFinish?()
        }
    }

    /// Pause playback, preserving the current position.
    func pause() {
        player?.pause()
        stopProgressTimer()
    }

    /// Resume from the paused position.
    func resume() {
        player?.play()
        startProgressTimer()
    }

    func stop() {
        stopProgressTimer()
        player?.stop()
        player = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopProgressTimer()
        onFinish?()
    }

    // MARK: - Progress timer

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let p = self.player else { return }
            self.onProgress?(p.currentTime, p.duration)
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
