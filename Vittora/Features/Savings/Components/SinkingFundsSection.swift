import SwiftUI
import VittoraCore

/// Sinking funds (M2.5.5): what each account's goals claim against what it holds.
///
/// Shown above the goal list because an over-allocated account invalidates the
/// progress shown below it — a goal reading "80% saved" means nothing if the
/// account it draws on has already been promised to two other goals.
///
/// Renders nothing when no goal is linked to an account, which is the common
/// case for a single-goal user, so the screen is unchanged for them.
struct SinkingFundsSection: View {
    let allocations: [SinkingFundAllocationEngine.AccountAllocation]

    var body: some View {
        if !allocations.isEmpty {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Text(String(localized: "Funded From"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)

                ForEach(allocations) { allocation in
                    card(allocation)
                }
            }
            .accessibilityIdentifier("sinking-funds-section")
        }
    }

    private func card(_ allocation: SinkingFundAllocationEngine.AccountAllocation) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                HStack {
                    Text(allocation.accountName)
                        .font(VTypography.body)
                        .foregroundStyle(VColors.textPrimary)
                    Spacer()
                    Text(currency(allocation.accountBalance, allocation))
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                        .monospacedDigit()
                }

                ProgressView(value: allocation.allocatedFraction)
                    .tint(allocation.isOverAllocated ? VColors.warning : VColors.primary)
                    .accessibilityHidden(true)

                if allocation.isOverAllocated {
                    // The number that matters: money promised twice.
                    Label {
                        Text(String(localized: "\(currency(allocation.overAllocationAmount, allocation)) more is promised to goals than this account holds."))
                            .font(VTypography.caption1)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(VColors.warning)
                } else {
                    HStack {
                        Text(String(localized: "Unallocated"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                        Spacer()
                        Text(currency(allocation.unallocated, allocation))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                            .monospacedDigit()
                    }
                }

                Divider()

                ForEach(allocation.goals) { goal in
                    HStack(spacing: VSpacing.sm) {
                        Circle()
                            .fill(Color(hex: goal.colorHex) ?? VColors.primary)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(goal.name)
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(currency(goal.allocatedAmount, allocation))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                            .monospacedDigit()
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(allocation))
        }
    }

    private func currency(
        _ amount: Decimal,
        _ allocation: SinkingFundAllocationEngine.AccountAllocation
    ) -> String {
        amount.formatted(.currency(code: allocation.currencyCode))
    }

    /// Combined into one element: read goal by goal it is a list of numbers with
    /// no stated relationship to the balance above them.
    private func accessibilityLabel(
        _ allocation: SinkingFundAllocationEngine.AccountAllocation
    ) -> String {
        if allocation.isOverAllocated {
            return String(localized: "\(allocation.accountName), holding \(currency(allocation.accountBalance, allocation)), is over-allocated by \(currency(allocation.overAllocationAmount, allocation)) across \(allocation.goals.count) goals.")
        }
        return String(localized: "\(allocation.accountName), holding \(currency(allocation.accountBalance, allocation)), has \(currency(allocation.unallocated, allocation)) unallocated across \(allocation.goals.count) goals.")
    }
}
