//
//  GlassComponents.swift
//  supertonic2-coreml-ios-test
//
//  iOS 26 "Liquid Glass" design system.
//  Provides reusable translucent glass-morphism components using a
//  warm white + burnt orange palette.
//

import SwiftUI

// MARK: - Color palette

extension Color {
    /// Warm cream background — lightest stop.
    static let glassDeepIndigo = Color(red: 0.99, green: 0.97, blue: 0.94)
    /// Warm cream background — mid stop.
    static let glassDeepPurple = Color(red: 0.97, green: 0.94, blue: 0.89)
    /// Warm cream background — darkest stop.
    static let glassDeepBlue   = Color(red: 0.94, green: 0.91, blue: 0.85)
    /// Primary accent — burnt orange (#CC5914).
    static let glassAccent      = Color(red: 0.80, green: 0.35, blue: 0.08)
    /// Secondary accent — warm amber (#F29919).
    static let glassAccent2     = Color(red: 0.95, green: 0.60, blue: 0.10)
    /// Glass surface tint — black at very low opacity for subtle depth on light bg.
    static let glassSurface     = Color.black.opacity(0.03)
    /// Glass border — thin warm-grey line.
    static let glassBorder      = Color.black.opacity(0.08)
    /// Danger / destructive — muted red.
    static let glassDanger      = Color(red: 1.0, green: 0.27, blue: 0.35)
    /// Primary text — warm near-black.
    static let glassText        = Color(red: 0.10, green: 0.08, blue: 0.06)
    /// Secondary / muted text.
    static let glassTextMuted   = Color(red: 0.10, green: 0.08, blue: 0.06).opacity(0.45)
}

// MARK: - Global background gradient

/// Full-screen warm cream gradient used as the app background.
struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.glassDeepIndigo, .glassDeepPurple, .glassDeepBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Ambient warm blobs — burnt orange + amber at very low opacity.
            Circle()
                .fill(Color.glassAccent.opacity(0.09))
                .frame(width: 340, height: 340)
                .offset(x: -80, y: -200)
                .blur(radius: 90)

            Circle()
                .fill(Color.glassAccent2.opacity(0.10))
                .frame(width: 280, height: 280)
                .offset(x: 120, y: 120)
                .blur(radius: 80)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass card

/// A frosted-glass card container suited for a light background.
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    // Frosted base
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                    // Subtle surface tint
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.glassSurface)
                    // Warm specular border
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.black.opacity(0.10), Color.black.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Glass button styles

/// Primary action button — burnt orange gradient fill.
struct GlassPrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }
            configuration.label
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color.glassAccent, Color.glassAccent2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .shadow(color: Color.glassAccent.opacity(0.30), radius: 8, x: 0, y: 4)
        .opacity(configuration.isPressed ? 0.8 : 1.0)
        .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Secondary action button — translucent glass fill with burnt orange tint.
struct GlassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.glassAccent)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.glassAccent.opacity(0.08))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.glassAccent.opacity(0.30), lineWidth: 1)
                }
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Destructive button — muted red tint.
struct GlassDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.glassDanger)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.glassDanger.opacity(0.10))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.glassDanger.opacity(0.22), lineWidth: 1)
                }
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Glass text field

/// A glass-styled text field for single-line input.
struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .foregroundColor(.glassText)
            .padding(12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.glassSurface)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.glassBorder, lineWidth: 1)
                }
            )
    }
}

// MARK: - Glass text editor

/// A glass-styled multi-line text editor.
struct GlassTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 140

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: minHeight)
            .scrollContentBackground(.hidden)
            .foregroundColor(.glassText)
            .padding(10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.glassSurface)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.glassBorder, lineWidth: 1)
                }
            )
    }
}

// MARK: - Section header

struct GlassSectionHeader: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let img = systemImage {
                Image(systemName: img)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.glassAccent)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.glassTextMuted)
                .textCase(.uppercase)
                .tracking(0.8)
        }
    }
}

// MARK: - Progress pill

/// Animated pill that shows progress or a status label.
struct GlassStatusPill: View {
    let text: String
    var systemImage: String? = nil
    var color: Color = .glassAccent

    var body: some View {
        HStack(spacing: 6) {
            if let img = systemImage {
                Image(systemName: img)
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.28), lineWidth: 1)
                )
        )
    }
}

// MARK: - Divider

struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.07))
            .frame(height: 1)
    }
}

// MARK: - Waveform Bars

/// Animated bar-chart waveform driven by normalised meter levels (0…1).
/// Designed for display inside a coloured circle, so bars are `.white`.
struct WaveformBarsView: View {
    /// Normalised power levels, one per bar. Values in [0, 1].
    var levels: [Float]
    /// When `false` all bars collapse to idle height with no animation.
    var isActive: Bool

    private let barCount = 20
    private let minHeightFraction: CGFloat = 0.12
    private let maxHeightFraction: CGFloat = 0.85

    var body: some View {
        GeometryReader { geo in
            let maxH = geo.size.height
            let barW = max(2, (geo.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount))

            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { i in
                    let level: CGFloat = {
                        guard isActive && !levels.isEmpty else { return minHeightFraction }
                        let idx = i * levels.count / barCount
                        return minHeightFraction + CGFloat(levels[idx]) * (maxHeightFraction - minHeightFraction)
                    }()

                    RoundedRectangle(cornerRadius: barW / 2)
                        .fill(Color.white.opacity(0.88))
                        .frame(width: barW, height: maxH * level)
                        .animation(
                            isActive
                                ? .easeInOut(duration: 0.18).repeatForever(autoreverses: true)
                                : .easeOut(duration: 0.25),
                            value: level
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
