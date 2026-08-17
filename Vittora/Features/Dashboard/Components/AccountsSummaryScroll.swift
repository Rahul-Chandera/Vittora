import SwiftUI
import VittoraCore

struct AccountsSummaryScroll: View {
    let accounts: [AccountEntity]
    let onSelect: (UUID) -> Void
    /// Opens account management (list / edit / delete). Optional so existing call sites compile.
    var onManage: (() -> Void)?
    /// Creates the first/next account. Optional so existing call sites compile.
    var onAdd: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Button {
                onManage?()
            } label: {
                HStack {
                    Text(String(localized: "Accounts"))
                        .font(VTypography.subheadline)
                        .foregroundColor(VColors.textSecondary)
                    Spacer()
                    if onManage != nil {
                        Text(String(localized: "Manage"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.primaryOnSurface)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(VColors.primaryOnSurface)
                            .accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(onManage == nil)
            .accessibilityIdentifier("dashboard-accounts-manage")
            .accessibilityLabel(String(localized: "Manage accounts"))
            .accessibilityHint(String(localized: "Opens the accounts list"))

            if accounts.isEmpty {
                VStack(spacing: VSpacing.sm) {
                    Text(String(localized: "No accounts yet"))
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.textTertiary)
                    if onAdd != nil {
                        Button {
                            onAdd?()
                        } label: {
                            Label(String(localized: "Add Account"), systemImage: "plus.circle.fill")
                                .font(VTypography.subheadline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VColors.primary)
                        .accessibilityIdentifier("dashboard-accounts-add")
                    }
                }
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
                        .font(VTypography.caption1Bold)
                        .foregroundStyle(VColors.primaryOnSurface)
                        .frame(width: 28, height: 28)
                        .background(VColors.primary.opacity(0.12))
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    Text(account.name)
                        .font(VTypography.body)
                        .foregroundColor(VColors.textPrimary)
                        .adaptiveLineLimit(1)
                }

                Text(formattedBalance(account.balance))
                    .font(VTypography.amountSmall)
                    .foregroundColor(account.type.isAsset ? VColors.textPrimary : VColors.expense)
                    .amountScaling()

                Text(account.type.displayName)
                    .font(VTypography.callout)
                    .foregroundColor(VColors.textSecondary)
            }
            .padding(VSpacing.md)
            .frame(width: 140, alignment: .leading)
            .background(VColors.secondaryGroupedBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(String(localized: "Opens account details"))
    }

    private func formattedBalance(_ balance: Decimal) -> String {
        balance.formatted(.currency(code: account.currencyCode))
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
