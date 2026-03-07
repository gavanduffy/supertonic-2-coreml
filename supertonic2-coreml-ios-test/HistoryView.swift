//
//  HistoryView.swift
//  supertonic2-coreml-ios-test
//
//  Displays past TTS readings and lets the user replay them.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: TTSViewModel
    @ObservedObject private var history = HistoryManager.shared

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Group {
            if history.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No history yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Items you read aloud will appear here.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(history.items) { item in
                        historyRow(item)
                    }
                    .onDelete(perform: history.remove)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear all") { history.clearAll() }
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func historyRow(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.subheadline)
                .lineLimit(1)
            Text(item.textPreview)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            HStack {
                Text(dateFormatter.string(from: item.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if item.audioURL != nil {
                    Button(action: { replayItem(item) }) {
                        Image(systemName: viewModel.isPlaying ? "stop.circle" : "play.circle")
                            .font(.title2)
                    }
                    .accessibilityLabel(viewModel.isPlaying ? "Stop" : "Play")
                }
                Button(action: { loadItemForEditing(item) }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                }
                .accessibilityLabel("Load full text for editing")
            }
        }
        .padding(.vertical, 4)
    }

    private func replayItem(_ item: HistoryItem) {
        if viewModel.isPlaying {
            viewModel.togglePlay()
            return
        }
        if let url = item.audioURL {
            viewModel.playExisting(url: url)
        }
    }

    private func loadItemForEditing(_ item: HistoryItem) {
        // Load the full original text, not just the preview snippet.
        viewModel.text = item.fullText
        viewModel.sourceURL = item.sourceURL
    }
}
