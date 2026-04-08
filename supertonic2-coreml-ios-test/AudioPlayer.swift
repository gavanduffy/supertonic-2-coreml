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

    /// Normalised RMS meter levels per channel, each in [0, 1].
    /// Sampled from the latest `updateMeters()` call; returns empty array when idle.
    var meterLevels: [Float] {
        guard let player else { return [] }
        let count = player.numberOfChannels
        return (0 ..< count).map { ch in
            let db = player.averagePower(forChannel: ch)
            // Map -60 dB … 0 dB → 0 … 1 (clamp below -60 to zero)
            let norm = (db + 60) / 60
            return max(0, min(1, norm))
        }
    }

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
            player.isMeteringEnabled = true
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

    /// Seek to an absolute position in the current audio file.
    /// - Parameter time: Target position in seconds; clamped to [0, duration].
    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = max(0, min(time, player.duration))
        // Emit a progress update immediately so the UI reflects the change.
        onProgress?(player.currentTime, player.duration)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopProgressTimer()
        onFinish?()
    }

    // MARK: - Progress timer

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let p = self.player else { return }
            p.updateMeters()
            self.onProgress?(p.currentTime, p.duration)
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
