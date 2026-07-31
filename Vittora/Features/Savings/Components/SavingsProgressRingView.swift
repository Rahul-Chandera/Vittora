import SwiftUI
import VittoraCore

/// Circular progress ring with percentage label inside.
struct SavingsProgressRingView: View {
    let progress: Double  // 0.0 – 1.0
    let color: Color
    var size: CGFloat = 80
    var lineWidth: CGFloat = 8
    var showLabel = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            // Track must clear non-text contrast (≥3:1) on secondary cards —
            // color.opacity(0.2) falls well below and trips Apple's sampler.
            Circle()
                .stroke(VColors.textTertiary, lineWidth: lineWidth)

            // Fill
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progress >= 1 ? VColors.income : color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.6), value: progress)

            // At accessibility sizes the percentage cannot fit the fixed ring
            // without clipping; clipped glyphs fail Apple's contrast sampler.
            // Parent cards already expose progress via accessibilityValue.
            if showLabel, !dynamicTypeSize.isAccessibilitySize {
                if progress >= 1 {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.28, weight: .bold))
                        .foregroundStyle(VColors.textPrimary)
                } else {
                    Text("\(Int(progress * 100))%")
                        .font(size < 80 ? .caption.bold() : .title2.bold())
                        .foregroundStyle(VColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Savings progress"))
        .accessibilityValue(
            progress >= 1
                ? String(localized: "Goal reached")
                : "\(Int(progress * 100))%"
        )
    }
}
