import SwiftUI
import VittoraCore

struct AccountRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let account: AccountEntity

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.sm))
            : AnyLayout(HStackLayout(spacing: VSpacing.md))
        layout {
            AccountTypeIcon(type: account.type, size: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(account.name)
                    .font(VTypography.bodyBold)
                    .foregroundColor(VColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(account.type.displayName)
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textPrimary)
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: VSpacing.xxs) {
                Text(account.balance.formatted(.currency(code: account.currencyCode)))
                    .font(VTypography.bodyBold)
                    .foregroundColor(.primary)
                if account.isArchived {
                    Text(String(localized: "Archived"))
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.textTertiary)
                        .padding(.horizontal, VSpacing.xs)
                        .padding(.vertical, 2)
                        .background(VColors.tertiaryBackground)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, VSpacing.xs)
        .contentShape(Rectangle())
        .vittoraPointerHighlight()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

private extension AccountRowView {
    var accountTypeDescription: String {
        account.type.rawValue
            .capitalized
            .replacingOccurrences(of: "Creditcard", with: "Credit Card")
            .replacingOccurrences(of: "Digitalwallet", with: "Digital Wallet")
    }

    var accessibilityLabel: String {
        var parts = [
            account.name,
            accountTypeDescription,
            account.balance.formatted(.currency(code: account.currencyCode))
        ]

        if account.isArchived {
            parts.append(String(localized: "Archived"))
        }

        return parts.joined(separator: ", ")
    }
}

#Preview {
    List {
        AccountRowView(account: AccountEntity(
            name: "Chase Checking",
            type: .bank,
            balance: 3_450.00,
            currencyCode: "USD"
        ))
        AccountRowView(account: AccountEntity(
            name: "Visa Credit Card",
            type: .creditCard,
            balance: -1_200.50,
            currencyCode: "USD"
        ))
        AccountRowView(account: AccountEntity(
            name: "Cash Wallet",
            type: .cash,
            balance: 85.00,
            currencyCode: "USD",
            isArchived: true
        ))
    }
}
