import SwiftUI

struct PayeeRowView: View {
    let payee: PayeeEntity

    var body: some View {
        HStack(spacing: VSpacing.md) {
            ZStack {
                Circle()
                    .fill(payee.type == .business ? VColors.primary.opacity(0.15) : VColors.income.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: payee.type == .business ? "building.2.fill" : "person.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(payee.type == .business ? VColors.primary : VColors.income)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(payee.name)
                    .font(VTypography.body)
                    .foregroundColor(VColors.textPrimary)
                HStack(spacing: VSpacing.xs) {
                    Text(payee.type == .business ? String(localized: "Business") : String(localized: "Person"))
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.textSecondary)
                    if let phone = payee.phone {
                        Text("·")
                            .foregroundColor(VColors.textTertiary)
                        Text(phone)
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(VColors.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, VSpacing.xxs)
    }
}

#Preview {
    List {
        PayeeRowView(payee: PayeeEntity(
            name: "Apple Inc.",
            type: .business,
            phone: "+1 800-275-2273"
        ))
        PayeeRowView(payee: PayeeEntity(
            name: "John Smith",
            type: .person,
            email: "john@example.com"
        ))
    }
}
