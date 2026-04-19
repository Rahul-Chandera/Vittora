import SwiftUI

struct BudgetProgressRing: View {
    let progress: Double  // 0.0 to 1.0+
    let size: CGFloat
    var animated: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(VColors.tertiaryBackground, lineWidth: 12)

            // Progress arc
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    arcGradient,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .if(animated && !reduceMotion) { view in
                    view.animation(.easeInOut(duration: 0.6), value: progress)
                }

            // Center text
            VStack(spacing: VSpacing.xs) {
                Text("\(Int(min(progress * 100, 999)))%")
                    .font(VTypography.title2)
                    .foregroundColor(VColors.textPrimary)

                Text(statusLabel)
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Budget progress"))
        .accessibilityValue(String(localized: "\(Int(min(progress * 100, 999))) percent, \(statusLabel)"))
    }

    private var statusLabel: String {
        if progress >= 1.0 {
            return String(localized: "Over Budget")
        } else if progress >= 0.9 {
            return String(localized: "Critical")
        } else if progress >= 0.75 {
            return String(localized: "Warning")
        } else {
            return String(localized: "On Track")
        }
    }

    private var arcGradient: LinearGradient {
        if progress >= 0.9 {
            return LinearGradient(
                gradient: Gradient(colors: [VColors.budgetDanger, VColors.budgetDanger.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if progress >= 0.75 {
            return LinearGradient(
                gradient: Gradient(colors: [VColors.budgetWarning, VColors.budgetWarning.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [VColors.budgetSafe, VColors.budgetSafe.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

#Preview {
    VStack(spacing: VSpacing.xl) {
        HStack(spacing: VSpacing.xl) {
            VStack(alignment: .center, spacing: VSpacing.md) {
                BudgetProgressRing(progress: 0.45, size: 120)
                Text("Safe")
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
            }

            VStack(alignment: .center, spacing: VSpacing.md) {
                BudgetProgressRing(progress: 0.82, size: 120)
                Text("Warning")
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
            }

            VStack(alignment: .center, spacing: VSpacing.md) {
                BudgetProgressRing(progress: 1.15, size: 120)
                Text("Over Budget")
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
            }
        }

        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
