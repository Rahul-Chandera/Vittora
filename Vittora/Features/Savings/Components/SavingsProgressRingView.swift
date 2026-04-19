import SwiftUI

/// Circular progress ring with percentage label inside.
struct SavingsProgressRingView: View {
    let progress: Double  // 0.0 – 1.0
    let color: Color
    var size: CGFloat = 80
    var lineWidth: CGFloat = 8
    var showLabel = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            // Fill
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progress >= 1 ? VColors.income : color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.6), value: progress)

            if showLabel {
                if progress >= 1 {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.28, weight: .bold))
                        .foregroundStyle(VColors.income)
                } else {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
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
