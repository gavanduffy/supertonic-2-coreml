//
//  URLInputView.swift
//  supertonic2-coreml-ios-test
//
//  Tab view for entering a URL, fetching its content, and reading it aloud.
//

import SwiftUI

struct URLInputView: View {
    @ObservedObject var viewModel: TTSViewModel

    @State private var urlString: String = ""
    @State private var isFetching: Bool = false
    @State private var fetchError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Paste a URL and the app will extract the article text and read it to you.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                urlInputRow

                if isFetching {
                    HStack {
                        ProgressView()
                        Text("Fetching article…")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                if let err = fetchError {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                if !viewModel.text.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted text")
                            .font(.subheadline)
                        Text(viewModel.text)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(10)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    speakButton
                }
            }
            .padding()
        }
    }

    private var urlInputRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("URL")
                .font(.subheadline)
            HStack {
                TextField("https://example.com/article", text: $urlString)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: pasteFromClipboard) {
                    Image(systemName: "doc.on.clipboard")
                }
                .accessibilityLabel("Paste URL from clipboard")

                Button(action: fetchURL) {
                    Image(systemName: "arrow.down.circle.fill")
                }
                .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty || isFetching)
                .accessibilityLabel("Fetch article")
            }
        }
    }

    private var speakButton: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.generate() }) {
                HStack {
                    if viewModel.isGenerating {
                        ProgressView()
                    }
                    Text(viewModel.isGenerating ? "Generating…" : "▶ Read aloud")
                }
            }
            .disabled(viewModel.isGenerating || viewModel.isLoadingModels || viewModel.availableVoices.isEmpty)
            .buttonStyle(.borderedProminent)

            if viewModel.audioURL != nil {
                Button(action: { viewModel.togglePlay() }) {
                    Text(viewModel.isPlaying ? "Stop" : "Play again")
                }
                .buttonStyle(.bordered)
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
                // Treat as plain text — switch to text input
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
