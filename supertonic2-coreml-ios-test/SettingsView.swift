//
//  SettingsView.swift
//  supertonic2-coreml-ios-test
//
//  Dedicated settings tab — voice, speed, steps, compute units.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: TTSViewModel

    var body: some View {
        Form {
            Section("Voice") {
                Picker("Voice", selection: $viewModel.selectedVoice) {
                    ForEach(viewModel.availableVoices, id: \.self) { voice in
                        Text(voice).tag(voice)
                    }
                }
                .disabled(viewModel.availableVoices.isEmpty || viewModel.isGenerating)

                Picker("Language", selection: $viewModel.language) {
                    ForEach(TTSService.Language.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }

            Section("Generation") {
                Stepper(value: $viewModel.steps, in: 1...30) {
                    Text("Diffusion steps: \(viewModel.steps)")
                }

                VStack(alignment: .leading) {
                    Text(String(format: "Speed: %.2f×", viewModel.speed))
                    Slider(value: $viewModel.speed, in: 0.75...1.4, step: 0.01)
                }

                VStack(alignment: .leading) {
                    Text(String(format: "Silence between chunks: %.2f s", viewModel.silenceSeconds))
                    Slider(value: $viewModel.silenceSeconds, in: 0.0...0.6, step: 0.05)
                }
            }

            Section(header: Text("Compute units"), footer: Text("'All' uses the Neural Engine when available.")) {
                Picker("Compute units", selection: $viewModel.computeUnits) {
                    ForEach(TTSService.ComputeUnits.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .disabled(viewModel.isGenerating || viewModel.isLoadingModels)
            }

            if let loadSeconds = viewModel.modelLoadSeconds {
                Section("Model info") {
                    let reason = viewModel.modelLoadReason?.displayName ?? "Load"
                    let units = viewModel.modelLoadComputeUnits?.displayName ?? "Unknown"
                    Text(String(format: "Last load (%@, %@): %.2f s", reason, units, loadSeconds))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
