//
//  NowPlayingSheet.swift
//  supertonic2-coreml-ios-test
//
//  Full-screen Now Playing sheet — tap the MiniPlayerBar to expand.
//

import SwiftUI

struct NowPlayingSheet: View {
    @ObservedObject var viewModel: TTSViewModel
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            LiquidGlassBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Drag handle ──────────────────────────────────────────────
                Capsule()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // ── Artwork circle ───────────────────────────────────
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.glassAccent, .glassAccent2],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 140, height: 140)
                                .shadow(color: .glassAccent.opacity(0.35), radius: 24, x: 0, y: 8)

                            if viewModel.isPlaying && !viewModel.meterLevels.isEmpty {
                                WaveformBarsView(levels: viewModel.meterLevels, isActive: true)
                                    .frame(width: 80, height: 56)
                            } else {
                                Image(systemName: viewModel.isPlaying ? "waveform" : "speaker.fill")
                                    .font(.system(size: 52, weight: .semibold))
                                    .foregroundColor(.white)
                                    .modifier(NowPlayingWaveEffect(isActive: viewModel.isPlaying))
                            }
                        }
                        .padding(.top, 16)

                        // ── Track title ──────────────────────────────────────
                        VStack(spacing: 6) {
                            Text(viewModel.nowPlayingTitle.isEmpty ? "Supertonic TTS" : viewModel.nowPlayingTitle)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.glassText)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 24)

                            if viewModel.isPaused {
                                Text("Paused")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.glassAccent.opacity(0.85))
                            }
                        }

                        // ── Scrubber ─────────────────────────────────────────
                        GlassCard(padding: 16) {
                            VStack(spacing: 8) {
                                // Progress slider
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.black.opacity(0.08))
                                            .frame(height: 5)
                                        Capsule()
                                            .fill(LinearGradient(
                                                colors: [.glassAccent, .glassAccent2],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            .frame(
                                                width: geo.size.width * max(0, min(1, viewModel.playbackProgress)),
                                                height: 5
                                            )
                                        // Scrub thumb
                                        Circle()
                                            .fill(Color.glassAccent)
                                            .frame(width: 14, height: 14)
                                            .offset(x: geo.size.width * max(0, min(1, viewModel.playbackProgress)) - 7)
                                    }
                                }
                                .frame(height: 14)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let width = UIScreen.main.bounds.width - 64 // approx card width
                                            let fraction = max(0, min(1, value.location.x / width))
                                            let targetTime = fraction * viewModel.totalDuration
                                            viewModel.seekTo(targetTime)
                                        }
                                )

                                // Time labels
                                HStack {
                                    Text(formatTime(viewModel.currentTime))
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.glassTextMuted)
                                    Spacer()
                                    Text(formatTime(viewModel.totalDuration))
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.glassTextMuted)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // ── Playback controls ────────────────────────────────
                        HStack(spacing: 32) {
                            // Skip backward
                            Button(action: { viewModel.skipBackward() }) {
                                Image(systemName: "gobackward.15")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundColor(viewModel.isPlaying || viewModel.isPaused ? .glassAccent : .glassTextMuted)
                                    .frame(width: 52, height: 52)
                            }
                            .disabled(!viewModel.isPlaying && !viewModel.isPaused)
                            .accessibilityLabel("Skip back 15 seconds")

                            // Play / Pause
                            Button(action: { viewModel.togglePlay() }) {
                                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 68, height: 68)
                                    .background(
                                        Circle()
                                            .fill(LinearGradient(
                                                colors: [.glassAccent, .glassAccent2],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            .shadow(color: .glassAccent.opacity(0.40), radius: 12, x: 0, y: 4)
                                    )
                            }
                            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

                            // Skip forward
                            Button(action: { viewModel.skipForward() }) {
                                Image(systemName: "goforward.15")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundColor(viewModel.isPlaying || viewModel.isPaused ? .glassAccent : .glassTextMuted)
                                    .frame(width: 52, height: 52)
                            }
                            .disabled(!viewModel.isPlaying && !viewModel.isPaused)
                            .accessibilityLabel("Skip forward 15 seconds")
                        }

                        // ── Info footer ──────────────────────────────────────
                        GlassCard(padding: 16) {
                            VStack(spacing: 10) {
                                infoRow(icon: "person.wave.2.fill", label: "Voice", value: viewModel.selectedVoice)
                                infoRow(icon: "speedometer", label: "Speed", value: String(format: "%.1f×", viewModel.speed))
                                if viewModel.playbackRemaining > 0 {
                                    infoRow(icon: "clock", label: "Remaining", value: formatTime(viewModel.playbackRemaining))
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // ── Stop button ──────────────────────────────────────
                        Button(action: {
                            viewModel.stopPlayback()
                            isPresented = false
                        }) {
                            Label("Stop & Close", systemImage: "stop.fill")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(GlassDestructiveButtonStyle())
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.glassAccent)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.glassTextMuted)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.glassText)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        let m = s / 60
        let rem = s % 60
        return String(format: "%d:%02d", m, rem)
    }
}

// MARK: - Symbol effect helper

private struct NowPlayingWaveEffect: ViewModifier {
    let isActive: Bool
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.symbolEffect(.variableColor.iterative, isActive: isActive)
        } else {
            content
        }
    }
}

#Preview {
    NowPlayingSheet(viewModel: TTSViewModel(), isPresented: .constant(true))
}
