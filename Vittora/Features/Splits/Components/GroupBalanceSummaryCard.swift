import SwiftUI
import VittoraCore

/// Shows the simplified "who owes whom" settlement list for a group.
struct GroupBalanceSummaryCard: View {
    let balances: [MemberBalance]
    let memberNames: [UUID: String]

    var body: some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Label(String(localized: "Settle Up"), systemImage: "arrow.left.arrow.right.circle.fill")
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textPrimary)

                if balances.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: VSpacing.xs) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(VColors.income)
                            Text(String(localized: "All settled up!"))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, VSpacing.sm)
                } else {
                    ForEach(Array(balances.enumerated()), id: \.offset) { _, balance in
                        BalanceRow(
                            balance: balance,
                            fromName: memberNames[balance.fromMemberID] ?? String(localized: "Unknown"),
                            toName: memberNames[balance.toMemberID] ?? String(localized: "Unknown")
                        )
                    }
                }
            }
        }
    }
}

private struct BalanceRow: View {
    @Environment(\.currencyCode) private var currencyCode

    let balance: MemberBalance
    let fromName: String
    let toName: String

    var body: some View {
        HStack(spacing: VSpacing.sm) {
            // Avatar from-person
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(VColors.textPrimary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(fromName)
                    .font(VTypography.caption1.bold())
                    .foregroundStyle(VColors.textPrimary)
                Text(String(localized: "owes"))
                    .font(VTypography.caption2)
                    .foregroundStyle(VColors.textSecondary)
            }

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(VColors.textSecondary)
                .accessibilityHidden(true)

            // Avatar to-person
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(VColors.textPrimary)
                .accessibilityHidden(true)

            Text(toName)
                .font(VTypography.caption1.bold())
                .foregroundStyle(VColors.textPrimary)

            Spacer()

            VAmountText(expense: balance.amount, size: .body)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(fromName) owes \(toName)"))
        .accessibilityValue(balance.amount.formatted(.currency(code: currencyCode)))
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let chars = parts.prefix(2).compactMap { $0.first }.map { String($0) }
        return chars.joined().uppercased()
    }
}
