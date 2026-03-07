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
        ZStack {
            LiquidGlassBackground()

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
        }
        .navigationTitle("")
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var pageHeader: some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(red: 0.40, green: 0.55, blue: 1.0),
                                     Color(red: 0.30, green: 0.80, blue: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("Customise voice, speed, and hardware")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
        }
    }

    // MARK: - Voice

    private var voiceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionHeader(title: "Voice & Language", systemImage: "mic.fill")
                GlassDivider()

                settingsRow(label: "Voice", icon: "person.wave.2") {
                    Picker("Voice", selection: $viewModel.selectedVoice) {
                        ForEach(viewModel.availableVoices, id: \.self) { v in
                            Text(v).tag(v)
                        }
                    }
                    .disabled(viewModel.availableVoices.isEmpty || viewModel.isGenerating)
                    .pickerStyle(.menu)
                    .tint(.glassAccent)
                }

                GlassDivider()

                settingsRow(label: "Language", icon: "globe") {
                    Picker("Language", selection: $viewModel.language) {
                        ForEach(TTSService.Language.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.glassAccent)
                }
            }
        }
    }

    // MARK: - Generation

    private var generationCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionHeader(title: "Generation", systemImage: "waveform.path.ecg")
                GlassDivider()

                // Steps stepper
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 14))
                            .foregroundColor(.glassAccent)
                            .frame(width: 24)
                        Text("Diffusion steps")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Stepper("\(viewModel.steps)", value: $viewModel.steps, in: 1...30)
                        .labelsHidden()
                        .foregroundColor(.white)
                    Text("\(viewModel.steps)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.glassAccent)
                        .frame(minWidth: 28)
                }

                GlassDivider()

                // Speed slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 14))
                            .foregroundColor(.glassAccent)
                            .frame(width: 24)
                        Text("Speed")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.2f×", viewModel.speed))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.glassAccent)
                    }
                    glassSlider(value: $viewModel.speed, range: 0.75...1.4, step: 0.01)
                }

                GlassDivider()

                // Silence slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.badge.minus")
                            .font(.system(size: 14))
                            .foregroundColor(.glassAccent)
                            .frame(width: 24)
                        Text("Silence between chunks")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.2fs", viewModel.silenceSeconds))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.glassAccent)
                    }
                    glassSlider(value: $viewModel.silenceSeconds, range: 0.0...0.6, step: 0.05)
                }
            }
        }
    }

    // MARK: - Compute units

    private var computeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionHeader(title: "Compute Units", systemImage: "cpu.fill")
                GlassDivider()

                Text("'All' uses the Neural Engine when available for fastest inference.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))

                Picker("Compute units", selection: $viewModel.computeUnits) {
                    ForEach(TTSService.ComputeUnits.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .disabled(viewModel.isGenerating || viewModel.isLoadingModels)
            }
        }
    }

    // MARK: - Model info

    @ViewBuilder
    private var modelInfoCard: some View {
        if let loadSeconds = viewModel.modelLoadSeconds {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    GlassSectionHeader(title: "Model Info", systemImage: "brain.head.profile")
                    GlassDivider()

                    let reason = viewModel.modelLoadReason?.displayName ?? "Load"
                    let units  = viewModel.modelLoadComputeUnits?.displayName ?? "Unknown"

                    HStack(spacing: 20) {
                        modelInfoItem(label: "Load type", value: reason)
                        modelInfoItem(label: "Units", value: units)
                        modelInfoItem(label: "Load time", value: String(format: "%.2fs", loadSeconds))
                    }
                }
            }
        }
    }

    private func modelInfoItem(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
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
                .foregroundColor(.glassAccent)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white)
            Spacer()
            content()
        }
    }

    private func glassSlider(value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        Slider(value: value, in: range, step: step)
            .tint(
                LinearGradient(
                    colors: [.glassAccent, .glassAccent2],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}
