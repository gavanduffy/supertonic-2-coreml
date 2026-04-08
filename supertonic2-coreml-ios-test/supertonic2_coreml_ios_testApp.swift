//
//  supertonic2_coreml_ios_testApp.swift
//  supertonic2-coreml-ios-test
//
//  Created by Nader Beyzaei on 2026-01-16.
//

import SwiftUI

@main
struct supertonic2_coreml_ios_testApp: App {
    @StateObject private var viewModel = TTSViewModel()

    private let appGroupID = "group.com.nbeyzaei.supertonic2-coreml-ios-test"
    private let pendingTextKey = "shared_pending_text"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onOpenURL { url in
                    guard url.scheme == "supertonic" else { return }
                    if let defaults = UserDefaults(suiteName: appGroupID),
                       let text = defaults.string(forKey: pendingTextKey), !text.isEmpty {
                        viewModel.text = text
                        defaults.removeObject(forKey: pendingTextKey)
                        defaults.synchronize()
                    }
                }
        }
    }
}
