//
//  HistoryManager.swift
//  supertonic2-coreml-ios-test
//
//  Persists recent TTS items so the user can replay past readings.
//

import Foundation
import SwiftUI

/// A single entry in the reading history.
struct HistoryItem: Identifiable, Codable {
    let id: UUID
    let title: String
    /// Short preview shown in the history list (≤ 200 chars).
    let textPreview: String
    /// Full text used for re-generation or editing.
    let fullText: String
    let sourceURL: String?
    let audioFileName: String?
    let date: Date
    let language: String
    /// Last playback position in seconds; 0 means start from beginning.
    var resumePosition: Double

    init(
        id: UUID = UUID(),
        title: String,
        fullText: String,
        sourceURL: String? = nil,
        audioFileName: String? = nil,
        date: Date = Date(),
        language: String = "en",
        resumePosition: Double = 0
    ) {
        self.id = id
        self.title = title
        self.fullText = fullText
        self.textPreview = String(fullText.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceURL = sourceURL
        self.audioFileName = audioFileName
        self.date = date
        self.language = language
        self.resumePosition = resumePosition
    }

    /// Resolved URL for the saved audio file (if it still exists on disk).
    var audioURL: URL? {
        guard let fileName = audioFileName else { return nil }
        return HistoryManager.audioDirectory.appendingPathComponent(fileName)
    }
}

@MainActor
@Observable final class HistoryManager {
    static let shared = HistoryManager()

    private(set) var items: [HistoryItem] = []

    private static let maxItems = 50
    /// Re-entrancy guard: prevents save → push → merge → save loops.
    private var isMerging = false

    nonisolated static var audioDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("tts_audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var storageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("tts_history.json")
    }

    private init() {
        load()
        mergeFromCloud()
    }

    // MARK: - Public API

    func add(
        title: String,
        text: String,
        sourceURL: String? = nil,
        audioFileURL: URL? = nil,
        language: String = "en"
    ) {
        let item = HistoryItem(
            title: title,
            fullText: text,
            sourceURL: sourceURL,
            audioFileName: audioFileURL?.lastPathComponent,
            language: language
        )
        items.insert(item, at: 0)
        if items.count > Self.maxItems {
            // Remove the oldest items, deleting their audio files.
            let removed = items.dropFirst(Self.maxItems)
            for old in removed {
                if let url = old.audioURL {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            items = Array(items.prefix(Self.maxItems))
        }
        save()
    }

    /// Update the saved resume position for a history item.
    func updateResumePosition(for itemID: UUID, time: Double) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].resumePosition = time
        save()
    }

    func remove(at offsets: IndexSet) {
        let toDelete = offsets.map { items[$0] }
        for item in toDelete {
            if let url = item.audioURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        items.remove(atOffsets: offsets)
        save()
    }

    func clearAll() {
        for item in items {
            if let url = item.audioURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        items.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL, options: .atomic)
            // Push the updated list to iCloud (skip during a merge to avoid loops).
            if !isMerging {
                CloudSyncManager.shared.push(items: items)
            }
        } catch {
            print("HistoryManager save error: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            items = try JSONDecoder().decode([HistoryItem].self, from: data)
        } catch {
            print("HistoryManager load error: \(error)")
        }
    }

    // MARK: - iCloud Sync

    /// Merge items received from iCloud KV store into the local list.
    /// Strategy: union by UUID, sort by date descending, cap at maxItems.
    func mergeFromCloud() {
        guard !isMerging else { return }
        guard let cloudItems = CloudSyncManager.shared.pull(), !cloudItems.isEmpty else { return }

        isMerging = true
        defer { isMerging = false }

        // Build a dictionary of current local items keyed by id.
        var merged: [UUID: HistoryItem] = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        for cloudItem in cloudItems {
            // Only add items not already present locally; never overwrite local data
            // (local resume positions and audio files take precedence).
            if merged[cloudItem.id] == nil {
                merged[cloudItem.id] = cloudItem
            }
        }

        // Sort by date descending, cap at maxItems.
        let sorted = merged.values
            .sorted { $0.date > $1.date }
            .prefix(Self.maxItems)

        items = Array(sorted)
        // Persist the merged list locally (isMerging=true so push is skipped).
        save()
    }
}
