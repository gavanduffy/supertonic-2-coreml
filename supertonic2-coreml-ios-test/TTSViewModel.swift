//
//  TTSViewModel.swift
//  supertonic2-coreml-ios-test
//
//  Created by Codex.
//

import Foundation

@MainActor
@Observable final class TTSViewModel {
    enum ModelLoadReason: String {
        case warmup
        case onDemand
        case settingsChange

        var displayName: String {
            switch self {
            case .warmup:
                return "Warm-up"
            case .onDemand:
                return "On-demand"
            case .settingsChange:
                return "Reload"
            }
        }

        var loadingMessage: String {
            switch self {
            case .warmup:
                return "Warming up Core ML models…"
            case .onDemand:
                return "Loading Core ML models…"
            case .settingsChange:
                return "Reloading Core ML models…"
            }
        }
    }

    struct Metrics {
        let audioSeconds: Double
        let elapsedSeconds: Double
        let timing: TTSService.Timing
        let memoryBeforeMB: Double?
        let memoryAfterMB: Double?

        var rtf: Double {
            guard audioSeconds > 0 else { return 0 }
            return elapsedSeconds / audioSeconds
        }
    }

    struct SamplePrompt: Identifiable {
        let id = UUID()
        let title: String
        let text: String
        let language: TTSService.Language
    }

    var text: String = "This is Supertonic 2 running on Core ML with int8 weights, tuned for faster inference on older iPhones."
    var selectedVoice: String = "F1"
    var language: TTSService.Language = .en
    var steps: Int = 20
    var speed: Double = 1.05
    var silenceSeconds: Double = 0.3
    var computeUnits: TTSService.ComputeUnits = .all
    /// The URL that was used to populate the current text (if any).
    var sourceURL: String?

    var isGenerating: Bool = false
    var isPlaying: Bool = false
    var isPaused: Bool = false
    var isLoadingModels: Bool = false
    var errorMessage: String?
    var metrics: Metrics?
    var audioURL: URL?
    var availableVoices: [String] = []
    var modelLoadSeconds: Double?
    var modelLoadReason: ModelLoadReason?
    var modelLoadComputeUnits: TTSService.ComputeUnits?
    var currentLoadReason: ModelLoadReason?
    /// Current playback title shown in the mini NowPlaying bar.
    var nowPlayingTitle: String = ""
    /// Playback progress 0–1.
    var playbackProgress: Double = 0
    /// Remaining seconds of current audio.
    var playbackRemaining: Double = 0
    /// Normalised meter levels [0…1] per channel, updated every 0.5 s while playing.
    var meterLevels: [Float] = []

    let samples: [SamplePrompt] = [
        SamplePrompt(
            title: "Warm intro",
            text: "Hello. This is a quick Core ML quality check on an iPhone XR. We want steady latency and clear voice.",
            language: .en
        ),
        SamplePrompt(
            title: "Tech update",
            text: "We trimmed memory by compressing weights and kept the full pipeline in Core ML for better stability.",
            language: .en
        ),
        SamplePrompt(
            title: "Spanish sample",
            text: "Hola. Esta es una prueba breve para revisar claridad y ritmo en el dispositivo.",
            language: .es
        )
    ]

    private var service: TTSService?
    private var loadedComputeUnits: TTSService.ComputeUnits?
    private let player = AudioPlayer()
    private var pendingGenerate: Bool = false
    private var pendingModelLoad: Bool = false
    private var pendingLoadReason: ModelLoadReason = .onDemand
    /// The history item whose audio is currently playing (if any).
    private var currentPlayingHistoryItemID: UUID?

    func startup() {
        // Warm-start the app by loading voices and preloading models.
        loadVoices()
        warmUpModels()
        // Register remote command handlers for lock-screen control.
        NowPlayingManager.shared.registerCommands(
            onPlay:         { [weak self] in DispatchQueue.main.async { self?.resumeOrPlay() } },
            onPause:        { [weak self] in DispatchQueue.main.async { self?.pausePlayback() } },
            onStop:         { [weak self] in DispatchQueue.main.async { self?.stopPlayback() } },
            onSkipForward:  { [weak self] in DispatchQueue.main.async { self?.skipForward() } },
            onSkipBackward: { [weak self] in DispatchQueue.main.async { self?.skipBackward() } }
        )
        // Wire progress updates from the audio player.
        player.onProgress = { [weak self] current, total in
            guard let self, total > 0 else { return }
            let levels = self.player.meterLevels
            DispatchQueue.main.async {
                self.playbackProgress = current / total
                self.playbackRemaining = max(0, total - current)
                self.meterLevels = levels
                NowPlayingManager.shared.updateElapsed(current)
            }
        }
    }

    func reloadModels() {
        requestModelLoad(reason: .settingsChange)
    }

    var loadingMessage: String {
        (currentLoadReason ?? .onDemand).loadingMessage
    }

    func loadVoices() {
        Task.detached {
            do {
                let voices = try TTSService.availableVoiceNames()
                await MainActor.run {
                    self.availableVoices = voices
                    if !voices.contains(self.selectedVoice) {
                        self.selectedVoice = voices.first ?? self.selectedVoice
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load voices: \(error.localizedDescription)"
                }
            }
        }
    }

    func generate() {
        // Ensure models are loaded for the current compute units before generating.
        guard let service = service, loadedComputeUnits == computeUnits else {
            pendingGenerate = true
            requestModelLoad(reason: .onDemand)
            return
        }
        isGenerating = true
        errorMessage = nil
        metrics = nil
        audioURL = nil

        let text = self.text
        let language = self.language
        let voice = self.selectedVoice
        let steps = self.steps
        let speed = self.speed
        let silence = self.silenceSeconds

        Task.detached {
            let start = Date()
            let memBefore = MemoryUsage.currentFootprintMB()
            do {
                // Run the full TTS pipeline off the main thread.
                let result = try service.synthesize(
                    text: text,
                    language: language,
                    voiceName: voice,
                    steps: steps,
                    speed: speed,
                    silenceSeconds: silence
                )
                let elapsed = Date().timeIntervalSince(start)
                let memAfter = MemoryUsage.currentFootprintMB()
                await MainActor.run {
                    self.audioURL = result.url
                    self.metrics = Metrics(
                        audioSeconds: result.audioSeconds,
                        elapsedSeconds: elapsed,
                        timing: result.timing,
                        memoryBeforeMB: memBefore,
                        memoryAfterMB: memAfter
                    )
                    self.isGenerating = false
                    // Save to history.
                    let title = self.sourceURL ?? String(text.prefix(60))
                    self.nowPlayingTitle = title
                    HistoryManager.shared.add(
                        title: title,
                        text: text,
                        sourceURL: self.sourceURL,
                        audioFileURL: result.url,
                        language: language.rawValue
                    )
                    self.play(url: result.url)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }

    func togglePlay() {
        if isPlaying {
            pausePlayback()
        } else if isPaused {
            resumeOrPlay()
        } else if let url = audioURL {
            play(url: url)
        }
    }

    /// Skip forward 15 seconds in the current playback.
    func skipForward() {
        guard isPlaying || isPaused else { return }
        player.seek(to: player.currentTime + 15)
        NowPlayingManager.shared.updateElapsed(player.currentTime, rate: isPlaying ? 1 : 0)
    }

    /// Skip backward 15 seconds in the current playback.
    func skipBackward() {
        guard isPlaying || isPaused else { return }
        player.seek(to: player.currentTime - 15)
        NowPlayingManager.shared.updateElapsed(player.currentTime, rate: isPlaying ? 1 : 0)
    }

    /// Total duration of the currently-loaded audio file (0 if none).
    var totalDuration: Double {
        player.duration
    }

    /// Current playback position in seconds.
    var currentTime: Double {
        player.currentTime
    }

    /// Seek to an absolute time in the current audio.
    func seekTo(_ time: Double) {
        guard isPlaying || isPaused else { return }
        player.seek(to: time)
        NowPlayingManager.shared.updateElapsed(player.currentTime, rate: isPlaying ? 1 : 0)
    }

    func stopPlayback() {
        saveResumePosition()
        player.stop()
        isPlaying = false
        isPaused = false
        playbackProgress = 0
        currentPlayingHistoryItemID = nil
        NowPlayingManager.shared.clear()
    }

    func pausePlayback() {
        saveResumePosition()
        player.pause()
        isPlaying = false
        isPaused = true
        NowPlayingManager.shared.updateElapsed(player.currentTime, rate: 0)
    }

    func resumeOrPlay() {
        if isPaused {
            player.resume()
            isPlaying = true
            isPaused = false
            NowPlayingManager.shared.updateElapsed(player.currentTime, rate: 1)
        } else if let url = audioURL {
            play(url: url)
        }
    }

    /// Play a previously-generated audio file (e.g. from history).
    /// - Parameters:
    ///   - url: Audio file URL to play.
    ///   - title: Display title for the NowPlaying bar.
    ///   - historyItemID: Optionally track this item so position can be saved on pause/stop.
    ///   - resumeFrom: Playback will seek to this position (seconds) after starting.
    func playExisting(url: URL, title: String = "", historyItemID: UUID? = nil, resumeFrom: Double = 0) {
        audioURL = url
        nowPlayingTitle = title.isEmpty ? "Supertonic TTS" : title
        currentPlayingHistoryItemID = historyItemID
        play(url: url)
        if resumeFrom > 0 {
            player.seek(to: resumeFrom)
        }
    }

    /// Persist the current playback position back to the history item (if any).
    private func saveResumePosition() {
        guard let itemID = currentPlayingHistoryItemID else { return }
        let t = player.currentTime
        guard t > 0 else { return }
        HistoryManager.shared.updateResumePosition(for: itemID, time: t)
    }

    private func play(url: URL) {
        let title = nowPlayingTitle.isEmpty ? "Supertonic TTS" : nowPlayingTitle
        player.play(url: url) { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
                self?.isPaused = false
                self?.playbackProgress = 0
                NowPlayingManager.shared.clear()
            }
        }
        isPlaying = true
        isPaused = false
        playbackProgress = 0
        // Update lock-screen metadata.
        NowPlayingManager.shared.update(
            title: title,
            duration: player.duration > 0 ? player.duration : 60
        )
    }

    private func warmUpModels() {
        Task { @MainActor in
            guard service == nil else { return }
            // Small delay allows the UI to settle before heavy model loads.
            try? await Task.sleep(nanoseconds: 250_000_000)
            requestModelLoad(reason: .warmup)
        }
    }

    private func requestModelLoad(reason: ModelLoadReason) {
        if isLoadingModels {
            // If the user changes settings during a load, queue a reload.
            if reason == .settingsChange {
                pendingModelLoad = true
                pendingLoadReason = reason
            }
            return
        }

        isLoadingModels = true
        currentLoadReason = reason
        errorMessage = nil
        let computeUnits = computeUnits
        let start = Date()

        Task.detached {
            do {
                // Model creation is expensive; keep it off the main thread.
                let service = try TTSService(computeUnits: computeUnits)
                let elapsed = Date().timeIntervalSince(start)
                await MainActor.run {
                    self.service = service
                    self.loadedComputeUnits = computeUnits
                    self.isLoadingModels = false
                    self.currentLoadReason = nil
                    self.modelLoadSeconds = elapsed
                    self.modelLoadReason = reason
                    self.modelLoadComputeUnits = computeUnits

                    // Apply any queued reloads and generation requests.
                    if self.pendingModelLoad {
                        self.pendingModelLoad = false
                        let pendingReason = self.pendingLoadReason
                        if pendingReason == .settingsChange && self.loadedComputeUnits != self.computeUnits {
                            self.requestModelLoad(reason: pendingReason)
                            return
                        }
                    }

                    if self.pendingGenerate {
                        self.pendingGenerate = false
                        self.generate()
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load models: \(error.localizedDescription)"
                    self.isLoadingModels = false
                    self.currentLoadReason = nil
                    self.pendingGenerate = false
                    if self.pendingModelLoad {
                        self.pendingModelLoad = false
                        let pendingReason = self.pendingLoadReason
                        self.requestModelLoad(reason: pendingReason)
                    }
                }
            }
        }
    }
}
