//  SupertonicIntents.swift
import AppIntents
import SwiftUI

struct SpeakTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Speak Text"
    static var description = IntentDescription("Read text aloud using Supertonic.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Text", description: "The text to speak")
    var text: String

    func perform() async throws -> some IntentResult {
        // Store in shared UserDefaults for the app to pick up
        let defaults = UserDefaults(suiteName: "group.com.nbeyzaei.supertonic2-coreml-ios-test")
        defaults?.set(text, forKey: "shared_pending_text")
        return .result()
    }
}

struct SupertonicShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SpeakTextIntent(),
            phrases: [
                "Speak with Supertonic",
                "Read text with \(.applicationName)"
            ],
            shortTitle: "Speak Text",
            systemImageName: "waveform"
        )
    }
}
