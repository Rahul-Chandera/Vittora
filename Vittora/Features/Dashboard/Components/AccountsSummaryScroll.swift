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
        VStack(alignment: .leading, spacing: VSpacing.sectionHeaderGap) {
            // Title outside the button, exactly as Budget and Recent
            // Transactions do it. Wrapping the whole row made this header
            // measurably taller than the others — 34 against 31 — and it also
            // meant tapping the word "Accounts" navigated away.
            HStack {
                Text(String(localized: "Accounts"))
                    .font(VTypography.subheadline)
                    .foregroundColor(VColors.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if onManage != nil {
                    Button {
                        onManage?()
                    } label: {
                        HStack(spacing: VSpacing.xxs) {
                            Text(String(localized: "Manage"))
                                .font(VTypography.callout)
                                .foregroundStyle(VColors.primaryOnSurface)
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(VColors.primaryOnSurface)
                                .accessibilityHidden(true)
                        }
                    }
                    // Tap target grown, then its layout cost reclaimed — see
                    // the same pairing on the Budget header.
                    .padding(.vertical, VSpacing.lg)
                    .contentShape(Rectangle())
                    .padding(.vertical, -VSpacing.lg)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dashboard-accounts-manage")
                    .accessibilityLabel(String(localized: "Manage accounts"))
                    .accessibilityHint(String(localized: "Opens the accounts list"))
                }
            }

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
                    // No vertical padding. These cards ARE this section's
                    // content — there is no wrapper card to hide it inside, so
                    // it read as extra space under the title and left Accounts
                    // the one section whose header gap did not match the rest.
                    // Nothing here casts a shadow that needs the room.
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
