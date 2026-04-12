import SwiftUI

struct AccountRowView: View {
    let account: AccountEntity

    var body: some View {
        HStack(spacing: VSpacing.md) {
            AccountTypeIcon(type: account.type, size: 40)

            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(account.name)
                    .font(VTypography.bodyBold)
                    .foregroundColor(VColors.textPrimary)
                Text(account.type.rawValue.capitalized.replacingOccurrences(of: "Creditcard", with: "Credit Card").replacingOccurrences(of: "Digitalwallet", with: "Digital Wallet"))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: VSpacing.xxs) {
                Text(account.balance.formatted(.currency(code: account.currencyCode)))
                    .font(VTypography.bodyBold)
                    .foregroundColor(account.balance >= 0 ? VColors.textPrimary : VColors.expense)
                if account.isArchived {
                    Text("Archived")
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
