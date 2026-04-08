//
//  HistoryView.swift
//  supertonic2-coreml-ios-test
//
//  Displays past TTS readings and lets the user replay them.
//  Redesigned with iOS 26 Liquid Glass aesthetics.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: TTSViewModel
    @ObservedObject private var history = HistoryManager.shared

    // B4: Search
    @State private var searchText = ""

    // B4: Export
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
        ZStack {
            LiquidGlassBackground()

            if history.items.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        // Format picker sheet
        .sheet(isPresented: $showingExportPicker) {
            exportFormatSheet
        }
        // Share sheet after export
        .sheet(item: $exportedFile) { file in
            ShareSheet(url: file.url)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.glassAccent.opacity(0.12))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(Color.glassAccent.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 100, height: 100)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.glassAccent)
            }

            VStack(spacing: 8) {
                Text("No history yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.glassText)
                Text("Items you read aloud will appear here.\nYou can replay or load them for editing.")
                    .font(.system(size: 14))
                    .foregroundColor(.glassTextMuted)
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
                    GlassCard(padding: 12) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.glassAccent, .glassAccent2],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Reading History")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.glassText)
                                Text("\(history.items.count) item\(history.items.count == 1 ? "" : "s")")
                                    .font(.system(size: 12))
                                    .foregroundColor(.glassTextMuted)
                            }
                            Spacer()
                            Button(action: { history.clearAll() }) {
                                Text("Clear all")
                            }
                            .buttonStyle(GlassDestructiveButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // B4: Search field
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.glassTextMuted)
                        TextField("Search history…", text: $searchText)
                            .font(.system(size: 14))
                            .foregroundColor(.glassText)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.glassTextMuted)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.glassAccent.opacity(0.15), lineWidth: 1))
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                VStack(spacing: 12) {
                    ForEach(filteredItems) { item in
                        historyRow(item)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 100)

                if filteredItems.isEmpty && !searchText.isEmpty {
                    Text("No results for "\(searchText)"")
                        .font(.system(size: 14))
                        .foregroundColor(.glassTextMuted)
                        .padding(.top, 24)
                }
            }
        }
        .searchable(text: $searchText)
    }

    // MARK: - History row

    @ViewBuilder
    private func historyRow(_ item: HistoryItem) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                // Title + language badge
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.glassText)
                        .lineLimit(1)
                    Spacer()
                    GlassStatusPill(
                        text: item.language.uppercased(),
                        color: .glassAccent
                    )
                }

                // Preview text
                Text(item.textPreview)
                    .font(.system(size: 12))
                    .foregroundColor(.glassTextMuted)
                    .lineLimit(2)

                GlassDivider()

                // Footer: date + actions
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundColor(.glassTextMuted)
                        Text(dateFormatter.string(from: item.date))
                            .font(.system(size: 11))
                            .foregroundColor(.glassTextMuted)
                    }

                    Spacer()

                    // Load for editing
                    Button(action: { loadItemForEditing(item) }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.glassAccent)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.glassAccent.opacity(0.12))
                                    .overlay(Circle().stroke(Color.glassAccent.opacity(0.25), lineWidth: 1))
                            )
                    }
                    .accessibilityLabel("Load full text for editing")

                    // B4: Export share button (only if audio exists)
                    if item.audioURL != nil {
                        Button(action: {
                            exportItem = item
                            showingExportPicker = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.glassAccent)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.glassAccent.opacity(0.12))
                                        .overlay(Circle().stroke(Color.glassAccent.opacity(0.25), lineWidth: 1))
                                )
                        }
                        .accessibilityLabel("Export audio")
                    }

                    // Play button (only if audio file exists)
                    if item.audioURL != nil {
                        Button(action: { replayItem(item) }) {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.glassAccent, .glassAccent2],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                )
                        }
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
                            .foregroundColor(.glassDanger)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.glassDanger.opacity(0.12))
                                    .overlay(Circle().stroke(Color.glassDanger.opacity(0.25), lineWidth: 1))
                            )
                    }
                    .accessibilityLabel("Delete")
                }
            }
        }
    }

    // MARK: - Export format picker sheet

    private var exportFormatSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose Export Format")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.glassText)
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
                                    .foregroundColor(.glassAccent)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.glassText)
                                    Text(formatDescription(format))
                                        .font(.system(size: 12))
                                        .foregroundColor(.glassTextMuted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.glassTextMuted)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.glassAccent.opacity(0.07))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.glassAccent.opacity(0.15), lineWidth: 1))
                            )
                        }
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
