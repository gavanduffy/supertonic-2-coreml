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

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

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
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.glassAccent2.opacity(0.15))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(Color.glassAccent2.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 100, height: 100)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.glassAccent2)
            }

            VStack(spacing: 8) {
                Text("No history yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("Items you read aloud will appear here.\nYou can replay or load them for editing.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.55))
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
                                        colors: [.glassAccent2, Color(red: 0.50, green: 0.30, blue: 1.0)],
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
                                    .foregroundColor(.white)
                                Text("\(history.items.count) item\(history.items.count == 1 ? "" : "s")")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.55))
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

                VStack(spacing: 12) {
                    ForEach(history.items) { item in
                        historyRow(item)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
        }
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
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    GlassStatusPill(
                        text: item.language.uppercased(),
                        color: .glassAccent2
                    )
                }

                // Preview text
                Text(item.textPreview)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(2)

                GlassDivider()

                // Footer: date + actions
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        Text(dateFormatter.string(from: item.date))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                    }

                    Spacer()

                    // Load for editing
                    Button(action: { loadItemForEditing(item) }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.glassAccent2)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.glassAccent2.opacity(0.12))
                                    .overlay(Circle().stroke(Color.glassAccent2.opacity(0.25), lineWidth: 1))
                            )
                    }
                    .accessibilityLabel("Load full text for editing")

                    // Play button (only if audio file exists)
                    if item.audioURL != nil {
                        Button(action: { replayItem(item) }) {
                            Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
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
                        .accessibilityLabel(viewModel.isPlaying ? "Stop" : "Play")
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

    // MARK: - Actions

    private func replayItem(_ item: HistoryItem) {
        if viewModel.isPlaying {
            viewModel.togglePlay()
            return
        }
        if let url = item.audioURL {
            viewModel.playExisting(url: url, title: item.title)
        }
    }

    private func loadItemForEditing(_ item: HistoryItem) {
        viewModel.text = item.fullText
        viewModel.sourceURL = item.sourceURL
    }
}
