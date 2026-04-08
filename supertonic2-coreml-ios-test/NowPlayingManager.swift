//
//  NowPlayingManager.swift
//  supertonic2-coreml-ios-test
//
//  Integrates with MPNowPlayingInfoCenter so the current TTS reading
//  appears on the lock screen, Control Centre, and AirPlay receivers.
//  Also registers MPRemoteCommandCenter handlers for play/pause/stop.
//

import Foundation
import MediaPlayer
import AVFoundation

@MainActor
final class NowPlayingManager {
    static let shared = NowPlayingManager()

    private init() {}

    // MARK: - Update lock-screen metadata

    /// Call this whenever playback starts or the current item changes.
    func update(
        title: String,
        artist: String = "Supertonic TTS",
        duration: TimeInterval,
        elapsed: TimeInterval = 0
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle:           title,
            MPMediaItemPropertyArtist:          artist,
            MPMediaItemPropertyMediaType:       MPMediaType.anyAudio.rawValue,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]

        // Artwork — use the app icon if available.
        if let icon = UIImage(named: "AppIcon"),
           let artwork = try? MPMediaItemArtwork(boundsSize: icon.size, requestHandler: { _ in icon }) {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Update the elapsed time and rate while playing (call from a timer).
    func updateElapsed(_ elapsed: TimeInterval, rate: Float = 1.0) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Clear the Now Playing info (call when playback stops).
    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Remote command registration

    /// Register play/pause/stop and optional skip remote commands.
    /// Pass closures from the ViewModel so the manager stays decoupled from
    /// business logic.  Providing skip handlers also enables the skip
    /// forward/backward buttons in Control Centre and on the lock screen.
    func registerCommands(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onSkipForward: (() -> Void)? = nil,
        onSkipBackward: (() -> Void)? = nil
    ) {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            onPlay()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }

        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { _ in
            onStop()
            return .success
        }

        // Disable track-level commands (not applicable for TTS).
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false

        // Skip forward / backward (15 s each).
        if let skipForward = onSkipForward {
            commandCenter.skipForwardCommand.isEnabled = true
            commandCenter.skipForwardCommand.preferredIntervals = [15]
            commandCenter.skipForwardCommand.addTarget { _ in
                skipForward()
                return .success
            }
        } else {
            commandCenter.skipForwardCommand.isEnabled = false
        }

        if let skipBackward = onSkipBackward {
            commandCenter.skipBackwardCommand.isEnabled = true
            commandCenter.skipBackwardCommand.preferredIntervals = [15]
            commandCenter.skipBackwardCommand.addTarget { _ in
                skipBackward()
                return .success
            }
        } else {
            commandCenter.skipBackwardCommand.isEnabled = false
        }
    }
}
