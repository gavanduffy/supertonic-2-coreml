//
//  ContentView.swift
//  supertonic2-coreml-ios-test
//
//  Created by Nader Beyzaei on 2026-01-16.
//

import SwiftUI

// MARK: - Availability helpers

/// Applies `.symbolEffect(.variableColor.iterative, isActive:)` on iOS 17+
/// and is a no-op on earlier OS versions.
private struct VariableColorSymbolEffect: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.symbolEffect(.variableColor.iterative, isActive: isActive)
        } else {
            content
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = TTSViewModel()
    @State private var showNowPlaying = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                // ── Read tab ────────────────────────────────────────────────
                ReadView(viewModel: viewModel)
                    .tabItem { Label("Read", systemImage: "text.bubble.fill") }

                // ── URL tab ─────────────────────────────────────────────────
                URLInputView(viewModel: viewModel)
                    .tabItem { Label("URL", systemImage: "link.circle.fill") }

                // ── History tab ─────────────────────────────────────────────
                HistoryView(viewModel: viewModel)
                    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

                // ── Settings tab ─────────────────────────────────────────────
                SettingsView(viewModel: viewModel)
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)

            // Mini NowPlaying bar — floats above the tab bar when playing.
            if viewModel.isPlaying || viewModel.isPaused || viewModel.audioURL != nil {
                MiniPlayerBar(viewModel: viewModel)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.isPlaying)
                    .onTapGesture { showNowPlaying = true }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Open Now Playing")
            }
        }
        .onAppear { viewModel.startup() }
        .onChange(of: viewModel.computeUnits) { _ in
            viewModel.reloadModels()
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingSheet(viewModel: viewModel, isPresented: $showNowPlaying)
        }
    }
}

// MARK: - Mini NowPlaying bar

struct MiniPlayerBar: View {
    @ObservedObject var viewModel: TTSViewModel

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                // Waveform icon or spinner
                ZStack {
                    Circle().fill(.tint).frame(width: 36, height: 36)
                    Image(systemName: viewModel.isPlaying ? "waveform" : "speaker.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .modifier(VariableColorSymbolEffect(isActive: viewModel.isPlaying))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.nowPlayingTitle.isEmpty ? "Supertonic TTS" : viewModel.nowPlayingTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if viewModel.isPlaying && viewModel.playbackRemaining > 0 {
                        Text(timeString(viewModel.playbackRemaining) + " remaining")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else if viewModel.isPaused {
                        Text("Paused")
                            .font(.system(size: 11))
                            .foregroundStyle(.tint)
                    } else {
                        Text("Ready to play")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Skip backward 15 s
                Button(action: { viewModel.skipBackward() }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("Skip back 15 seconds")
                .disabled(!viewModel.isPlaying && !viewModel.isPaused)

                // Play / Pause button
                Button(action: { viewModel.togglePlay() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(.tint, in: Circle())
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(viewModel.isPlaying ? "Pause playback" : "Play audio")

                // Skip forward 15 s
                Button(action: { viewModel.skipForward() }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("Skip forward 15 seconds")
                .disabled(!viewModel.isPlaying && !viewModel.isPaused)
            }
            .padding(.horizontal, 12)

            // Progress bar
            if viewModel.isPlaying && viewModel.playbackProgress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary).frame(height: 2)
                        Capsule().fill(.tint).frame(width: geo.size.width * viewModel.playbackProgress, height: 2)
                    }
                }
                .frame(height: 2)
                .padding(.top, 6)
            }
        }
        .padding(12)
        .glassEffect()
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        if s >= 60 {
            return "\(s / 60)m \(s % 60)s"
        }
        return "\(s)s"
    }
}

// MARK: - Read tab

/// The main "type or paste text and speak" screen.
struct ReadView: View {
    @ObservedObject var viewModel: TTSViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                inputCard
                actionCard
                metricsCard
                samplesCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    // MARK: Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.tint).frame(width: 48, height: 48)
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Supertonic TTS")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                Text("On-device · Int8 CoreML pipeline")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.isLoadingModels {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView()
                        .tint(.accentColor)
                        .scaleEffect(0.8)
                    Text(viewModel.loadingMessage)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            } else if !viewModel.availableVoices.isEmpty {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(12)
        .glassEffect()
    }

    // MARK: Input

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Text", systemImage: "doc.text")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: pasteText) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Paste")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .tint(.accentColor)
                .accessibilityLabel("Paste text from clipboard")
            }

            // Replaced custom editor with native TextEditor + glassEffect
            TextEditor(text: $viewModel.text)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(10)
                .glassEffect()
        }
        .padding(12)
        .glassEffect()
    }

    // MARK: Actions

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: { viewModel.generate() }) {
                    HStack(spacing: 6) {
                        if viewModel.isGenerating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.75)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(viewModel.isGenerating ? "Generating…" : "Generate")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(viewModel.isGenerating || viewModel.isLoadingModels || viewModel.availableVoices.isEmpty)

                if viewModel.audioURL != nil {
                    Button(action: { viewModel.togglePlay() }) {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(viewModel.isPlaying ? "Pause" : (viewModel.isPaused ? "Resume" : "Play"))
                        }
                    }
                    .buttonStyle(.glass)
                    .disabled(viewModel.isGenerating)
                }
            }
            .frame(maxWidth: .infinity)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(Color.red)
                    .font(.system(size: 13))
                    .padding(.top, 6)
            }
        }
        .padding(14)
        .glassEffect()
    }

    // MARK: Metrics

    @ViewBuilder
    private var metricsCard: some View {
        if let m = viewModel.metrics {
            VStack(alignment: .leading, spacing: 10) {
                Label("Performance", systemImage: "gauge.with.dots.needle.33percent")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Divider()

                HStack(spacing: 0) {
                    metricItem(label: "Audio", value: String(format: "%.2fs", m.audioSeconds))
                    metricItem(label: "Elapsed", value: String(format: "%.2fs", m.elapsedSeconds))
                    metricItem(label: "RTF", value: String(format: "%.2f×", m.rtf))
                }

                Divider()

                HStack(spacing: 0) {
                    metricItem(label: "DP", value: String(format: "%.2fs", m.timing.durationPredictor))
                    metricItem(label: "TE", value: String(format: "%.2fs", m.timing.textEncoder))
                    metricItem(label: "VE", value: String(format: "%.2fs", m.timing.vectorEstimator))
                    metricItem(label: "Voc", value: String(format: "%.2fs", m.timing.vocoder))
                }

                if let before = m.memoryBeforeMB, let after = m.memoryAfterMB {
                    Divider()
                    HStack(spacing: 4) {
                        Image(systemName: "memorychip")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f MB → %.1f MB", before, after))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .glassEffect()
        }
    }

    private func metricItem(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Samples

    private var samplesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sample Prompts", systemImage: "text.quote")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Divider()
            ForEach(viewModel.samples) { sample in
                Button(action: {
                    viewModel.text = sample.text
                    viewModel.language = sample.language
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 14))
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sample.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(sample.text)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                if sample.id != viewModel.samples.last?.id {
                    Divider()
                }
            }
        }
        .padding(12)
        .glassEffect()
    }

    // MARK: Helpers

    private func pasteText() {
        #if canImport(UIKit)
        if let str = UIPasteboard.general.string {
            viewModel.text = str
        }
        #endif
    }
}
