import SwiftUI

struct AccountsSummaryScroll: View {
    let accounts: [AccountEntity]
    let onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Accounts"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            if accounts.isEmpty {
                Text(String(localized: "No accounts yet"))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(VSpacing.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VSpacing.md) {
                        ForEach(accounts) { account in
                            AccountMiniCard(account: account) {
                                onSelect(account.id)
                            }
                        }
                    }
                    .padding(.horizontal, VSpacing.xxs)
                    .padding(.vertical, VSpacing.xs)
                }
            }
        }
    }
}

private struct AccountMiniCard: View {
    let account: AccountEntity
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                HStack(spacing: VSpacing.sm) {
                    Image(systemName: account.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VColors.primary)
                        .frame(width: 28, height: 28)
                        .background(VColors.primary.opacity(0.12))
                        .clipShape(Circle())

                    Text(account.name)
                        .font(VTypography.caption1Bold)
                        .foregroundColor(VColors.textPrimary)
                        .adaptiveLineLimit(1)
                }

                Text(formattedBalance(account.balance))
                    .font(VTypography.amountSmall)
                    .foregroundColor(account.type.isAsset ? VColors.textPrimary : VColors.expense)

                Text(account.type.rawValue.capitalized)
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.textSecondary)
            }
            .padding(VSpacing.md)
            .frame(width: 140, alignment: .leading)
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(String(localized: "Opens account details"))
    }

    private func formattedBalance(_ balance: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = account.currencyCode
        return formatter.string(from: balance as NSDecimalNumber) ?? balance.formatted(.currency(code: account.currencyCode))
    }

    private var accountTypeDescription: String {
        account.type.rawValue
            .capitalized
            .replacingOccurrences(of: "Creditcard", with: "Credit Card")
            .replacingOccurrences(of: "Digitalwallet", with: "Digital Wallet")
    }

    private var accessibilityLabel: String {
        [
            account.name,
            accountTypeDescription,
            formattedBalance(account.balance)
        ].joined(separator: ", ")
    }
}

#Preview {
    AccountsSummaryScroll(accounts: [], onSelect: { _ in })
        .padding()
}
