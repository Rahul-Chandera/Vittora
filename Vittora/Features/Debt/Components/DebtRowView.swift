import SwiftUI

struct DebtRowView: View {
    let entry: DebtLedgerEntry

    var body: some View {
        HStack(spacing: VSpacing.md) {
            // Avatar
            Circle()
                .fill(avatarColor)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(initials(entry.payee.name))
                        .font(VTypography.bodyBold)
                        .foregroundColor(.white)
                }

            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(entry.payee.name)
                    .font(VTypography.bodyBold)
                    .foregroundColor(VColors.textPrimary)

                HStack(spacing: VSpacing.sm) {
                    if entry.totalLent > 0 {
                        Text(String(localized: "owes you \(formattedAmount(entry.totalLent))"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.income)
                    }
                    if entry.totalBorrowed > 0 {
                        Text(String(localized: "you owe \(formattedAmount(entry.totalBorrowed))"))
                            .font(VTypography.caption2)
                            .foregroundColor(VColors.expense)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: VSpacing.xxs) {
                Text(formattedAmount(abs(entry.netBalance)))
                    .font(VTypography.amountSmall)
                    .foregroundColor(entry.netBalance >= 0 ? VColors.income : VColors.expense)

                if entry.entries.contains(where: { $0.isOverdue }) {
                    Text(String(localized: "Overdue"))
                        .font(VTypography.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, VSpacing.sm)
                        .padding(.vertical, VSpacing.xxs)
                        .background(VColors.expense)
                        .cornerRadius(VSpacing.cornerRadiusPill)
                }
            }
        }
        .padding(.vertical, VSpacing.xs)
    }

    private var avatarColor: Color {
        entry.netBalance >= 0 ? VColors.income : VColors.expense
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.compactMap { $0.first }.prefix(2)
        return letters.map(String.init).joined()
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        amount.formatted(currencyCode: "USD")
    }
}
