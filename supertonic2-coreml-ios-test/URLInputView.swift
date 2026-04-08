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
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.tint)
                    .frame(width: 48, height: 48)
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Read from URL")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Paste a link and we'll extract the article")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .glassEffect()
    }

    // MARK: - URL input card

    private var urlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Article URL", systemImage: "globe")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Divider()

            TextField("https://example.com/article", text: $urlString)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(12)
                .glassEffect()

            HStack(spacing: 10) {
                Button(action: pasteFromClipboard) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Paste URL")
                    }
                }
                .buttonStyle(.glass)

                Button(action: fetchURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Fetch")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty || isFetching)
            }
        }
        .padding(14)
        .glassEffect()
    }

    // MARK: - Fetching indicator

    private var fetchingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.accentColor)
            Text("Extracting article text…")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .glassEffect()
    }

    // MARK: - Error card

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.red)
                .opacity(0.9)
            Spacer()
        }
        .padding(14)
        .glassEffect()
    }

    // MARK: - Preview card

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Extracted Text", systemImage: "doc.plaintext")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Divider()

            Text(viewModel.text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(12)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

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
                .buttonStyle(.glassProminent)
                .disabled(viewModel.isGenerating || viewModel.isLoadingModels || viewModel.availableVoices.isEmpty)

                if viewModel.audioURL != nil {
                    Button(action: { viewModel.togglePlay() }) {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                            Text(viewModel.isPlaying ? "Pause" : (viewModel.isPaused ? "Resume" : "Play again"))
                        }
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .padding(14)
        .glassEffect()
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
                    viewModel.text = sanitizeForTTS(text)
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

    private func sanitizeForTTS(_ raw: String) -> String {
        // Remove emoji and non-ASCII symbols, normalize whitespace
        let noEmoji = raw.unicodeScalars.filter { scalar in
            !scalar.properties.isEmojiPresentation &&
            scalar.value < 0x10000
        }.reduce("") { $0 + String($1) }
        // Collapse multiple spaces/newlines
        let components = noEmoji.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
