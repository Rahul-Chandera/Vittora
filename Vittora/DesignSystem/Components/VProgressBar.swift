import SwiftUI

/// An animated budget progress bar with semantic coloring based on spending thresholds.
/// Changes color from green (safe) to orange (warning) to red (danger).
struct VProgressBar: View {
    let spent: Decimal
    let limit: Decimal
    let showLabel: Bool
    let animated: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        spent: Decimal,
        limit: Decimal,
        showLabel: Bool = true,
        animated: Bool = true
    ) {
        self.spent = spent
        self.limit = limit
        self.showLabel = showLabel
        self.animated = animated
    }

    var body: some View {
        VStack(spacing: VSpacing.sm) {
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: VSpacing.cornerRadiusSM)
                    .fill(VColors.tertiaryBackground)
                    .frame(height: 8)

                // Progress fill with gradient
                if progress > 0 {
                    RoundedRectangle(cornerRadius: VSpacing.cornerRadiusSM)
                        .fill(progressGradient)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(width: max(0, progress * 300), height: 8)
                        .if(animated && !reduceMotion) { view in
                            view.animation(.easeInOut(duration: 0.6), value: progress)
                        }
                }

                // Status indicator (non-color signal for warning/danger/overflow)
                if progress >= 0.75 {
                    HStack {
                        Spacer()
                        Image(systemName: progress > 1.0 ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(statusColor)
                            .padding(.horizontal, VSpacing.xs)
                            .accessibilityLabel(progress > 1.0
                                ? String(localized: "Over budget")
                                : progress >= 0.9
                                    ? String(localized: "Near limit")
                                    : String(localized: "Approaching limit"))
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Budget progress"))
            .accessibilityValue(accessibilityStatusLabel)

            if showLabel {
                HStack(spacing: VSpacing.md) {
                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        Text(String(localized: "Spent"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                        VAmountText(spent, size: .caption)
                    }

                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        Text(String(localized: "Limit"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                        VAmountText(limit, size: .caption)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: VSpacing.xs) {
                        Text(String(localized: "Progress"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.textSecondary)
                        HStack(spacing: VSpacing.xxs) {
                            if progress >= 1.0 {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(statusColor)
                                    .accessibilityHidden(true)
                            }
                            Text("\(progressPercentage)%")
                                .font(VTypography.caption1Bold)
                                .foregroundColor(statusColor)
                        }
                    }
                }
            }
        }
    }

    private var accessibilityStatusLabel: String {
        if progress > 1.0 {
            return "\(progressPercentage)%, \(String(localized: "over budget"))"
        } else if progress >= 0.9 {
            return "\(progressPercentage)%, \(String(localized: "near limit"))"
        } else {
            return "\(progressPercentage)%"
        }
    }

    private var progress: CGFloat {
        guard limit > 0 else { return 0 }
        return CGFloat(truncating: NSDecimalNumber(decimal: spent / limit))
    }

    private var progressPercentage: Int {
        Int(progress * 100)
    }

    private var statusColor: Color {
        if progress < 0.75 {
            return VColors.budgetSafe
        } else if progress < 0.9 {
            return VColors.budgetWarning
        } else {
            return VColors.budgetDanger
        }
    }

    private var progressGradient: LinearGradient {
        if progress < 0.75 {
            return LinearGradient(
                gradient: Gradient(colors: [VColors.budgetSafe, VColors.budgetSafe.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if progress < 0.9 {
            return LinearGradient(
                gradient: Gradient(colors: [VColors.budgetWarning, VColors.budgetWarning.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [VColors.budgetDanger, VColors.budgetDanger.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: VSpacing.xl) {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.lg) {
                Text("Budget Progress Examples")
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)

                VStack(alignment: .leading, spacing: VSpacing.md) {
                    Text("Safe (30%)")
                        .font(VTypography.subheadline)
                        .foregroundColor(VColors.textSecondary)
                    VProgressBar(spent: 300, limit: 1000, showLabel: true)
                }

                VStack(alignment: .leading, spacing: VSpacing.md) {
                    Text("Warning (80%)")
                        .font(VTypography.subheadline)
                        .foregroundColor(VColors.textSecondary)
                    VProgressBar(spent: 800, limit: 1000, showLabel: true)
                }

                VStack(alignment: .leading, spacing: VSpacing.md) {
                    Text("Danger (120% - Over Budget)")
                        .font(VTypography.subheadline)
                        .foregroundColor(VColors.textSecondary)
                    VProgressBar(spent: 1200, limit: 1000, showLabel: true)
                }

                VStack(alignment: .leading, spacing: VSpacing.md) {
                    Text("Compact (no label)")
                        .font(VTypography.subheadline)
                        .foregroundColor(VColors.textSecondary)
                    VProgressBar(spent: 450, limit: 1000, showLabel: false)
                }
            }
        }

        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
