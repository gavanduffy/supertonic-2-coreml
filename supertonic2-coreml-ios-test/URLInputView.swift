//
//  URLInputView.swift
//  supertonic2-coreml-ios-test
//
//  Tab view for entering a URL, fetching its content, and reading it aloud.
//  Redesigned with iOS 26 Liquid Glass aesthetics.
//

import SwiftUI

struct URLInputView: View {
    @ObservedObject var viewModel: TTSViewModel

    @State private var urlString: String = ""
    @State private var isFetching: Bool = false
    @State private var fetchError: String?

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(spacing: 16) {
                    pageHeader
                    urlCard
                    if isFetching { fetchingCard }
                    if let err = fetchError { errorCard(err) }
                    if !viewModel.text.isEmpty { previewCard }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var pageHeader: some View {
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
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Read from URL")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.glassText)
                    Text("Paste a link and we'll extract the article")
                        .font(.system(size: 12))
                        .foregroundColor(.glassTextMuted)
                }
                Spacer()
            }
        }
    }

    // MARK: - URL input card

    private var urlCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(title: "Article URL", systemImage: "globe")

                GlassDivider()

                GlassTextField(
                    placeholder: "https://example.com/article",
                    text: $urlString,
                    keyboardType: .URL
                )

                HStack(spacing: 10) {
                    Button(action: pasteFromClipboard) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Paste URL")
                        }
                    }
                    .buttonStyle(GlassSecondaryButtonStyle())

                    Button(action: fetchURL) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Fetch")
                        }
                    }
                    .buttonStyle(GlassPrimaryButtonStyle())
                    .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty || isFetching)
                }
            }
        }
    }

    // MARK: - Fetching indicator

    private var fetchingCard: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .glassAccent))
                Text("Extracting article text…")
                    .font(.system(size: 14))
                    .foregroundColor(.glassTextMuted)
                Spacer()
            }
        }
    }

    // MARK: - Error card

    private func errorCard(_ message: String) -> some View {
        GlassCard(padding: 14) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.glassDanger)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.glassDanger.opacity(0.9))
                Spacer()
            }
        }
    }

    // MARK: - Preview card

    private var previewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(title: "Extracted Text", systemImage: "doc.plaintext")

                GlassDivider()

                Text(viewModel.text)
                    .font(.system(size: 13))
                    .foregroundColor(.glassText)
                    .lineLimit(12)
                    .fixedSize(horizontal: false, vertical: true)

                GlassDivider()

                HStack(spacing: 12) {
                    Button(action: { viewModel.generate() }) {
                        HStack(spacing: 6) {
                            if viewModel.isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.75)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text(viewModel.isGenerating ? "Generating…" : "Read aloud")
                        }
                    }
                    .buttonStyle(GlassPrimaryButtonStyle())
                    .disabled(viewModel.isGenerating || viewModel.isLoadingModels || viewModel.availableVoices.isEmpty)

                    if viewModel.audioURL != nil {
                        Button(action: { viewModel.togglePlay() }) {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.isPlaying ? "pause.fill" : "arrow.clockwise")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(viewModel.isPlaying ? "Pause" : (viewModel.isPaused ? "Resume" : "Play again"))
                            }
                        }
                        .buttonStyle(GlassSecondaryButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        #if canImport(UIKit)
        if let str = UIPasteboard.general.string {
            if str.hasPrefix("http://") || str.hasPrefix("https://") {
                urlString = str
            } else {
                viewModel.text = str
            }
        }
        #endif
    }

    private func fetchURL() {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed) else {
            fetchError = "Invalid URL. Please check and try again."
            return
        }
        fetchError = nil
        isFetching = true
        viewModel.sourceURL = urlString

        Task {
            do {
                let text = try await URLTextFetcher.fetchText(from: url)
                await MainActor.run {
                    viewModel.text = text
                    isFetching = false
                }
            } catch {
                await MainActor.run {
                    fetchError = error.localizedDescription
                    isFetching = false
                }
            }
        }
    }
}
