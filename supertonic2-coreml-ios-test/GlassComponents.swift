//
//  GlassComponents.swift
//  supertonic2-coreml-ios-test
//
//  iOS 26 "Liquid Glass" design system.
//  Provides reusable translucent glass-morphism components that match the
//  frosted-glass aesthetic introduced in iOS 26.
//

import SwiftUI

// MARK: - Color palette

extension Color {
    /// Deep-space gradient stop #1 — rich indigo/violet base.
    static let glassDeepIndigo = Color(red: 0.06, green: 0.04, blue: 0.18)
    /// Deep-space gradient stop #2 — dark purple.
    static let glassDeepPurple = Color(red: 0.11, green: 0.04, blue: 0.22)
    /// Deep-space gradient stop #3 — near-black with blue tint.
    static let glassDeepBlue   = Color(red: 0.04, green: 0.07, blue: 0.20)
    /// Vibrant accent — electric teal used for interactive highlights.
    static let glassAccent      = Color(red: 0.20, green: 0.80, blue: 0.95)
    /// Secondary accent — soft lavender.
    static let glassAccent2     = Color(red: 0.65, green: 0.45, blue: 1.00)
    /// Glass surface tint — white at low opacity for a frosted panel.
    static let glassSurface     = Color.white.opacity(0.08)
    /// Glass border — thin specular highlight line.
    static let glassBorder      = Color.white.opacity(0.18)
    /// Danger / destructive — muted red.
    static let glassDanger      = Color(red: 1.0, green: 0.27, blue: 0.35)
}

// MARK: - Global background gradient

/// Full-screen aurora gradient used as the app background.
struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.glassDeepIndigo, .glassDeepPurple, .glassDeepBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Ambient colour blobs that give the aurora effect.
            Circle()
                .fill(Color.glassAccent2.opacity(0.18))
                .frame(width: 340, height: 340)
                .offset(x: -80, y: -200)
                .blur(radius: 90)

            Circle()
                .fill(Color.glassAccent.opacity(0.14))
                .frame(width: 280, height: 280)
                .offset(x: 120, y: 120)
                .blur(radius: 80)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass card

/// A frosted-glass card container.
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
                    // Specular highlight at top
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Glass button styles

/// Primary action button — vibrant gradient fill.
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
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .opacity(configuration.isPressed ? 0.8 : 1.0)
        .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Secondary action button — translucent glass fill.
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
                        .fill(Color.glassAccent.opacity(0.10))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.glassAccent.opacity(0.35), lineWidth: 1)
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
                        .fill(Color.glassDanger.opacity(0.12))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.glassDanger.opacity(0.25), lineWidth: 1)
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
            .foregroundColor(.white)
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
            .foregroundColor(.white)
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
                .foregroundColor(.white.opacity(0.6))
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
                .fill(color.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.30), lineWidth: 1)
                )
        )
    }
}

// MARK: - Divider

struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
    }
}
