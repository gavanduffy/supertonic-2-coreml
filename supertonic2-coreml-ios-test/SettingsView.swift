//
//  SettingsView.swift
//  supertonic2-coreml-ios-test
//
//  Dedicated settings tab — voice, speed, steps, compute units.
//  Redesigned with iOS 26 Liquid Glass aesthetics.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: TTSViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                pageHeader
                voiceCard
                generationCard
                computeCard
                modelInfoCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .navigationTitle("Settings")
    }

    // MARK: - Header

    private var pageHeader: some View {
        VStack {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.tint)
                        .frame(width: 48, height: 48)
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Customise voice, speed, and hardware")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .glassEffect()
    }

    // MARK: - Voice

    private var voiceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Voice & Language", systemImage: "mic.fill")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .tracking(0.8)

            Divider()

            settingsRow(label: "Voice", icon: "person.wave.2") {
                Picker("Voice", selection: $viewModel.selectedVoice) {
                    ForEach(viewModel.availableVoices, id: \.self) { v in
                        Text(voiceDisplayName(v)).tag(v)
                    }
                }
                .disabled(viewModel.availableVoices.isEmpty || viewModel.isGenerating)
                .pickerStyle(.menu)
                .tint(.accentColor)
            }

            Divider()

            settingsRow(label: "Language", icon: "globe") {
                Picker("Language", selection: $viewModel.language) {
                    ForEach(TTSService.Language.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .tint(.accentColor)
            }
        }
        .padding(16)
        .glassEffect()
    }

    // MARK: - Generation

    private var generationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Generation", systemImage: "waveform.path.ecg")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .tracking(0.8)

            Divider()

            // Steps stepper
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 14))
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    Text("Diffusion steps")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Stepper("\(viewModel.steps)", value: $viewModel.steps, in: 1...30)
                    .labelsHidden()
                    .foregroundStyle(.primary)
                Text("\(viewModel.steps)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(minWidth: 28)
            }

            Divider()

            // Speed slider
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 14))
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    Text("Speed")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(String(format: "%.2f×", viewModel.speed))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tint)
                }
                glassSlider(value: $viewModel.speed, range: 0.75...1.4, step: 0.01)
            }

            Divider()

            // Silence slider
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.badge.minus")
                        .font(.system(size: 14))
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    Text("Silence between chunks")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(String(format: "%.2fs", viewModel.silenceSeconds))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tint)
                }
                glassSlider(value: $viewModel.silenceSeconds, range: 0.0...0.6, step: 0.05)
            }
        }
        .padding(16)
        .glassEffect()
    }

    // MARK: - Compute units

    private var computeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Compute Units", systemImage: "cpu.fill")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .tracking(0.8)

            Divider()

            Text("'All' uses the Neural Engine when available for fastest inference.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Picker("Compute units", selection: $viewModel.computeUnits) {
                ForEach(TTSService.ComputeUnits.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .tint(.accentColor)
            .disabled(viewModel.isGenerating || viewModel.isLoadingModels)
        }
        .padding(16)
        .glassEffect()
    }

    // MARK: - Model info

    @ViewBuilder
    private var modelInfoCard: some View {
        if let loadSeconds = viewModel.modelLoadSeconds {
            VStack(alignment: .leading, spacing: 10) {
                Label("Model Info", systemImage: "brain.head.profile")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                Divider()

                let reason = viewModel.modelLoadReason?.displayName ?? "Load"
                let units  = viewModel.modelLoadComputeUnits?.displayName ?? "Unknown"

                HStack(spacing: 20) {
                    modelInfoItem(label: "Load type", value: reason)
                    modelInfoItem(label: "Units", value: units)
                    modelInfoItem(label: "Load time", value: String(format: "%.2fs", loadSeconds))
                }
            }
            .padding(16)
            .glassEffect()
        }
    }

    private func modelInfoItem(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func settingsRow<Content: View>(
        label: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
            Spacer()
            content()
        }
    }

    private func glassSlider(value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        Slider(value: value, in: range, step: step)
            .tint(.accentColor)
    }

    private func voiceDisplayName(_ id: String) -> String {
        switch id {
        case "F1": return "Sarah (Female)"
        case "F2": return "Emma (Female)"
        case "M1": return "James (Male)"
        case "M2": return "David (Male)"
        default: return id
        }
    }
}
