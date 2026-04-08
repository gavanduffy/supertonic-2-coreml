import SwiftUI

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
