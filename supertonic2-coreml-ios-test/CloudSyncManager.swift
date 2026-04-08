//
//  CloudSyncManager.swift
//  supertonic2-coreml-ios-test
//
//  Syncs TTS history across the user's iCloud-enabled devices via
//  NSUbiquitousKeyValueStore (iCloud KV store, up to 1 MB total).
//  Audio files remain local; items without a local audio file are still
//  shown in history so the user can re-generate speech on any device.
//

import Foundation

@MainActor
final class CloudSyncManager {
    static let shared = CloudSyncManager()

    private let store = NSUbiquitousKeyValueStore.default
    private let historyKey = "tts_history_items"

    private init() {
        // Listen for changes pushed from other devices.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        // Start synchronisation as soon as the app launches.
        store.synchronize()
    }

    // MARK: - Push

    /// Encode and upload `items` to the iCloud KV store.
    func push(items: [HistoryItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            store.set(data, forKey: historyKey)
            store.synchronize()
        } catch {
            print("CloudSyncManager push error: \(error)")
        }
    }

    // MARK: - Pull

    /// Decode items stored in the iCloud KV store, or nil if none exist yet.
    func pull() -> [HistoryItem]? {
        guard let data = store.data(forKey: historyKey) else { return nil }
        do {
            return try JSONDecoder().decode([HistoryItem].self, from: data)
        } catch {
            print("CloudSyncManager pull error: \(error)")
            return nil
        }
    }

    // MARK: - External-change notification

    @objc private nonisolated func storeDidChange(_ notification: Notification) {
        guard let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
              keys.contains(historyKey) else { return }
        // Dispatch the merge back to the main actor where HistoryManager lives.
        Task { @MainActor in
            HistoryManager.shared.mergeFromCloud()
        }
    }
}
