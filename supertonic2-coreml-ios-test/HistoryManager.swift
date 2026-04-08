//
//  HistoryManager.swift
//  supertonic2-coreml-ios-test
//
//  Persists recent TTS items so the user can replay past readings.
//

import Combine
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
final class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    @Published private(set) var items: [HistoryItem] = []

    private static let maxItems = 50

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
}
