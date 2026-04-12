import SwiftUI

struct CategoryRowView: View {
    let category: CategoryEntity

    private var tintColor: Color {
        Color(hex: category.colorHex) ?? .blue
    }

    var body: some View {
        HStack(spacing: VSpacing.md) {
            ZStack {
                Circle()
                    .fill(tintColor)
                    .opacity(0.15)
                    .frame(width: 40, height: 40)
                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(tintColor)
            }

            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(category.name)
                    .font(VTypography.body)
                    .foregroundColor(VColors.textPrimary)
                Text(category.type == .expense ? "Expense" : "Income")
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
            }

            Spacer()

            if category.isDefault {
                Text("Default")
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.textTertiary)
                    .padding(.horizontal, VSpacing.xs)
                    .padding(.vertical, 2)
                    .background(VColors.tertiaryBackground)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, VSpacing.xxs)
    }
}

#Preview {
    List {
        CategoryRowView(category: CategoryEntity(
            name: "Food & Dining",
            icon: "fork.knife",
            colorHex: "#FF6B35",
            type: .expense
        ))
        CategoryRowView(category: CategoryEntity(
            name: "Salary",
            icon: "dollarsign.circle.fill",
            colorHex: "#34C759",
            type: .income,
            isDefault: true
        ))
    }
}
