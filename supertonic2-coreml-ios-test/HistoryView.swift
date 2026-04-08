//
//  HistoryView.swift
//  supertonic2-coreml-ios-test
//
//  Displays past TTS readings and lets the user replay them.
//  Updated to use native iOS 26 Liquid Glass APIs.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: TTSViewModel
    @ObservedObject private var history = HistoryManager.shared

    // Search
    @State private var searchText = ""

    // Export
    @State private var exportItem: HistoryItem?
    @State private var exportFormat: AudioExportFormat = .m4a
    @State private var showingExportPicker = false
    @State private var exportedFile: ExportedFile?
    @State private var isExporting = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var filteredItems: [HistoryItem] {
        if searchText.isEmpty { return history.items }
        return history.items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.textPreview.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if history.items.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showingExportPicker) {
            exportFormatSheet
        }
        .sheet(item: $exportedFile) { file in
            ShareSheet(url: file.url)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.12))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(.tint.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 100, height: 100)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.tint)
            }

            VStack(spacing: 8) {
                Text("No history yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Items you read aloud will appear here.\nYou can replay or load them for editing.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - History list

    private var historyList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header row
                HStack {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(.tint.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Circle()
                                .stroke(.tint.opacity(0.25), lineWidth: 1)
                                .frame(width: 44, height: 44)
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.tint)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Reading History")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("\(history.items.count) item\(history.items.count == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: { history.clearAll() }) {
                            Text("Clear all")
                        }
                        .buttonStyle(.glass)
                        .tint(.red)
                    }
                    .padding(12)
                    .glassEffect()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                VStack(spacing: 12) {
                    ForEach(filteredItems) { item in
                        historyRow(item)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 100)

                if filteredItems.isEmpty && !searchText.isEmpty {
                    Text("No results for \"\(searchText)\"")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                }
            }
        }
        .searchable(text: $searchText)
    }

    // MARK: - History row

    @ViewBuilder
    private func historyRow(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title + language badge
            HStack(spacing: 8) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                // Language badge
                Text(item.language.uppercased())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.tint.opacity(0.12), in: Capsule())
                    .foregroundStyle(.tint)
            }

            // Preview text
            Text(item.textPreview)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Divider()

            // Footer: date + actions
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(dateFormatter.string(from: item.date))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Load for editing
                Button(action: { loadItemForEditing(item) }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Load full text for editing")

                // Export/share button
                if item.audioURL != nil {
                    Button(action: {
                        exportItem = item
                        showingExportPicker = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Export audio")
                }

                // Play button (only if audio file exists)
                if item.audioURL != nil {
                    Button(action: { replayItem(item) }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
                }

                // Delete button
                Button(action: {
                    if let idx = history.items.firstIndex(where: { $0.id == item.id }) {
                        history.remove(at: IndexSet(integer: idx))
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.glass)
                .tint(.red)
                .accessibilityLabel("Delete")
            }
        }
        .padding(14)
        .glassEffect()
    }

    // MARK: - Export format picker sheet

    private var exportFormatSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Choose Export Format")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 20)

                VStack(spacing: 12) {
                    ForEach(AudioExportFormat.allCases) { format in
                        Button(action: {
                            exportFormat = format
                            showingExportPicker = false
                            if let item = exportItem, let wav = item.audioURL {
                                startExport(wav: wav, item: item, format: format)
                            }
                        }) {
                            HStack {
                                Image(systemName: formatIcon(format))
                                    .font(.system(size: 20))
                                    .foregroundStyle(.tint)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text(formatDescription(format))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding(.horizontal, 20)

                if isExporting {
                    ProgressView("Exporting…")
                        .padding()
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingExportPicker = false }
                }
            }
        }
    }

    private func startExport(wav: URL, item: HistoryItem, format: AudioExportFormat) {
        isExporting = true
        Task {
            do {
                let exporter = AudioExporter()
                let url = try await exporter.export(
                    wavURL: wav,
                    format: format,
                    title: item.title,
                    artist: "Supertonic TTS"
                )
                await MainActor.run {
                    isExporting = false
                    exportedFile = ExportedFile(url: url)
                }
            } catch {
                await MainActor.run { isExporting = false }
            }
        }
    }

    private func formatIcon(_ format: AudioExportFormat) -> String {
        switch format {
        case .m4a: return "music.note"
        case .m4b: return "book.fill"
        case .mp3: return "waveform"
        }
    }

    private func formatDescription(_ format: AudioExportFormat) -> String {
        switch format {
        case .m4a: return "High quality AAC audio"
        case .m4b: return "Audiobook with chapters"
        case .mp3: return "Universal MP3 (iOS 17+)"
        }
    }

    // MARK: - Actions

    private func replayItem(_ item: HistoryItem) {
        if viewModel.isPlaying {
            viewModel.pausePlayback()
            return
        }
        if let url = item.audioURL {
            viewModel.playExisting(
                url: url,
                title: item.title,
                historyItemID: item.id,
                resumeFrom: item.resumePosition
            )
        }
    }

    private func loadItemForEditing(_ item: HistoryItem) {
        viewModel.text = item.fullText
        viewModel.sourceURL = item.sourceURL
    }
}

// MARK: - Helpers for share sheet

private struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
