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

    var body: some View {
        ZStack(alignment: .bottom) {
            LiquidGlassBackground()

            TabView {
                // ── Read tab ────────────────────────────────────────────────
                ReadView(viewModel: viewModel)
                    .tabItem {
                        Label("Read", systemImage: "text.bubble.fill")
                    }

                // ── URL tab ─────────────────────────────────────────────────
                URLInputView(viewModel: viewModel)
                    .tabItem {
                        Label("URL", systemImage: "link.circle.fill")
                    }

                // ── History tab ─────────────────────────────────────────────
                HistoryView(viewModel: viewModel)
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }

                // ── Settings tab ─────────────────────────────────────────────
                SettingsView(viewModel: viewModel)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)

            // Mini NowPlaying bar — floats above the tab bar when playing.
            if viewModel.isPlaying || viewModel.isPaused || viewModel.audioURL != nil {
                MiniPlayerBar(viewModel: viewModel)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.isPlaying)
            }
        }
        .onAppear { viewModel.startup() }
        .onChange(of: viewModel.computeUnits) { _ in
            viewModel.reloadModels()
        }
    }
}

// MARK: - Mini NowPlaying bar

struct MiniPlayerBar: View {
    @ObservedObject var viewModel: TTSViewModel

    var body: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                // Waveform icon or spinner
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.glassAccent, .glassAccent2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                    Image(systemName: viewModel.isPlaying ? "waveform" : "speaker.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .modifier(VariableColorSymbolEffect(isActive: viewModel.isPlaying))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.nowPlayingTitle.isEmpty ? "Supertonic TTS" : viewModel.nowPlayingTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if viewModel.isPlaying && viewModel.playbackRemaining > 0 {
                        Text(timeString(viewModel.playbackRemaining) + " remaining")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.55))
                    } else if viewModel.isPaused {
                        Text("Paused")
                            .font(.system(size: 11))
                            .foregroundColor(.glassAccent.opacity(0.75))
                    } else {
                        Text("Ready to play")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }

                Spacer()

                // Play / Stop button
                Button(action: { viewModel.togglePlay() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.glassAccent)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.glassAccent.opacity(0.15))
                                .overlay(Circle().stroke(Color.glassAccent.opacity(0.3), lineWidth: 1))
                        )
                }
                .accessibilityLabel(viewModel.isPlaying ? "Pause playback" : "Play audio")
            }

            // Progress bar
            if viewModel.isPlaying && viewModel.playbackProgress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 2)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [.glassAccent, .glassAccent2],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * viewModel.playbackProgress, height: 2)
                    }
                }
                .frame(height: 2)
                .padding(.top, 6)
            }
        }
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
        ZStack {
            LiquidGlassBackground()

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
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    // MARK: Header

    private var headerCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.glassAccent, .glassAccent2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Supertonic TTS")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("On-device · Int8 CoreML pipeline")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                if viewModel.isLoadingModels {
                    VStack(alignment: .trailing, spacing: 4) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .glassAccent))
                            .scaleEffect(0.8)
                        Text(viewModel.loadingMessage)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.trailing)
                    }
                } else if !viewModel.availableVoices.isEmpty {
                    GlassStatusPill(text: "Ready", systemImage: "checkmark.circle.fill", color: .glassAccent)
                }
            }
        }
    }

    // MARK: Input

    private var inputCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    GlassSectionHeader(title: "Text", systemImage: "doc.text")
                    Spacer()
                    Button(action: pasteText) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Paste")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.glassAccent)
                    }
                    .accessibilityLabel("Paste text from clipboard")
                }

                GlassTextEditor(text: $viewModel.text, minHeight: 140)
            }
        }
    }

    // MARK: Actions

    private var actionCard: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 12) {
                Button(action: { viewModel.generate() }) {
                    HStack(spacing: 6) {
                        if viewModel.isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.75)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(viewModel.isGenerating ? "Generating…" : "Generate")
                    }
                }
                .buttonStyle(GlassPrimaryButtonStyle())
                .disabled(viewModel.isGenerating || viewModel.isLoadingModels || viewModel.availableVoices.isEmpty)

                if viewModel.audioURL != nil {
                    Button(action: { viewModel.togglePlay() }) {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(viewModel.isPlaying ? "Pause" : (viewModel.isPaused ? "Resume" : "Play"))
                        }
                    }
                    .buttonStyle(GlassSecondaryButtonStyle())
                    .disabled(viewModel.isGenerating)
                }
            }
            .frame(maxWidth: .infinity)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.glassDanger)
                    .font(.system(size: 13))
                    .padding(.top, 6)
            }
        }
    }

    // MARK: Metrics

    @ViewBuilder
    private var metricsCard: some View {
        if let m = viewModel.metrics {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    GlassSectionHeader(title: "Performance", systemImage: "gauge.with.dots.needle.33percent")

                    GlassDivider()

                    HStack(spacing: 0) {
                        metricItem(label: "Audio", value: String(format: "%.2fs", m.audioSeconds))
                        metricItem(label: "Elapsed", value: String(format: "%.2fs", m.elapsedSeconds))
                        metricItem(label: "RTF", value: String(format: "%.2f×", m.rtf))
                    }

                    GlassDivider()

                    HStack(spacing: 0) {
                        metricItem(label: "DP", value: String(format: "%.2fs", m.timing.durationPredictor))
                        metricItem(label: "TE", value: String(format: "%.2fs", m.timing.textEncoder))
                        metricItem(label: "VE", value: String(format: "%.2fs", m.timing.vectorEstimator))
                        metricItem(label: "Voc", value: String(format: "%.2fs", m.timing.vocoder))
                    }

                    if let before = m.memoryBeforeMB, let after = m.memoryAfterMB {
                        GlassDivider()
                        HStack(spacing: 4) {
                            Image(systemName: "memorychip")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                            Text(String(format: "%.1f MB → %.1f MB", before, after))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                }
            }
        }
    }

    private func metricItem(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Samples

    private var samplesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(title: "Sample Prompts", systemImage: "text.quote")
                GlassDivider()
                ForEach(viewModel.samples) { sample in
                    Button(action: {
                        viewModel.text = sample.text
                        viewModel.language = sample.language
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 14))
                                .foregroundColor(.glassAccent2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sample.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(sample.text)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.vertical, 6)
                    }
                    if sample.id != viewModel.samples.last?.id {
                        GlassDivider()
                    }
                }
            }
        }
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
