//
//  ContentView.swift
//  supertonic2-coreml-ios-test
//
//  Created by Nader Beyzaei on 2026-01-16.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TTSViewModel()

    var body: some View {
        TabView {
            // ── Read tab ────────────────────────────────────────────────
            NavigationView {
                ReadView(viewModel: viewModel)
                    .navigationTitle("Read Aloud")
            }
            .tabItem {
                Label("Read", systemImage: "text.bubble")
            }

            // ── URL tab ─────────────────────────────────────────────────
            NavigationView {
                URLInputView(viewModel: viewModel)
                    .navigationTitle("URL")
            }
            .tabItem {
                Label("URL", systemImage: "link")
            }

            // ── History tab ─────────────────────────────────────────────
            NavigationView {
                HistoryView(viewModel: viewModel)
                    .navigationTitle("History")
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            // ── Settings tab ─────────────────────────────────────────────
            NavigationView {
                SettingsView(viewModel: viewModel)
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .onAppear { viewModel.startup() }
        .onChange(of: viewModel.computeUnits) { _ in
            viewModel.reloadModels()
        }
    }
}

// MARK: - Read tab

/// The main "type or paste text and speak" screen.
struct ReadView: View {
    @ObservedObject var viewModel: TTSViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if viewModel.isLoadingModels {
                    ProgressView(viewModel.loadingMessage)
                }

                inputSection
                actionSection
                metricsSection
                samplesSection

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Int8 CoreML pipeline")
                .font(.headline)
            Text("iOS 15+ • duration + text encoder + vector estimator + vocoder")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Text")
                    .font(.subheadline)
                Spacer()
                Button(action: pasteText) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(.footnote)
                }
                .accessibilityLabel("Paste text from clipboard")
            }
            TextEditor(text: $viewModel.text)
                .frame(minHeight: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.4))
                )
        }
    }

    private var actionSection: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.generate() }) {
                HStack {
                    if viewModel.isGenerating {
                        ProgressView()
                    }
                    Text(viewModel.isGenerating ? "Generating…" : "Generate")
                }
            }
            .disabled(viewModel.isGenerating || viewModel.isLoadingModels || viewModel.availableVoices.isEmpty)
            .buttonStyle(.borderedProminent)

            Button(action: { viewModel.togglePlay() }) {
                Text(viewModel.isPlaying ? "Stop" : "Play")
            }
            .disabled(viewModel.audioURL == nil || viewModel.isGenerating)
            .buttonStyle(.bordered)
        }
    }

    private var metricsSection: some View {
        Group {
            if let metrics = viewModel.metrics {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: "Audio: %.2fs • Elapsed: %.2fs • RTF: %.2fx",
                                metrics.audioSeconds, metrics.elapsedSeconds, metrics.rtf))
                        .font(.subheadline)
                    Text(String(format: "DP %.2fs • TE %.2fs • VE %.2fs • Voc %.2fs",
                                metrics.timing.durationPredictor,
                                metrics.timing.textEncoder,
                                metrics.timing.vectorEstimator,
                                metrics.timing.vocoder))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    if let before = metrics.memoryBeforeMB, let after = metrics.memoryAfterMB {
                        Text(String(format: "Memory footprint: %.1f MB → %.1f MB", before, after))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var samplesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sample prompts")
                .font(.subheadline)
            ForEach(viewModel.samples) { sample in
                Button(sample.title) {
                    viewModel.text = sample.text
                    viewModel.language = sample.language
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func pasteText() {
        #if canImport(UIKit)
        if let str = UIPasteboard.general.string {
            viewModel.text = str
        }
        #endif
    }
}
