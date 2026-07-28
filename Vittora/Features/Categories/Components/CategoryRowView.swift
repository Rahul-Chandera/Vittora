import SwiftUI
import VittoraCore

struct CategoryRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let category: CategoryEntity

    private var tintColor: Color {
        Color(hex: category.colorHex) ?? .blue
    }

    var body: some View {
        HStack(spacing: VSpacing.md) {
            ZStack {
                Circle()
                    .fill(VColors.tertiaryBackground)
                    .frame(width: 40, height: 40)
                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(VColors.textPrimary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(category.displayName)
                    .font(VTypography.body)
                    .foregroundColor(VColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(category.type == .expense ? String(localized: "Expense") : String(localized: "Income"))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textPrimary)
                if dynamicTypeSize.isAccessibilitySize, category.isDefault {
                    defaultBadge
                }
            }

            Spacer()

            if !dynamicTypeSize.isAccessibilitySize, category.isDefault {
                defaultBadge
            }
        }
        .padding(.vertical, VSpacing.xxs)
        .contentShape(Rectangle())
        .vittoraPointerHighlight()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.name)
        .accessibilityValue(
            category.isDefault
                ? String(localized: "\(categoryType), default")
                : categoryType
        )
    }

    private var categoryType: String {
        category.type == .expense ? String(localized: "Expense") : String(localized: "Income")
    }

    private var defaultBadge: some View {
        Text(String(localized: "Default"))
            .font(VTypography.caption2)
            .foregroundColor(VColors.textPrimary)
            .padding(.horizontal, VSpacing.xs)
            .padding(.vertical, 2)
            .background(VColors.tertiaryBackground)
            .cornerRadius(4)
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
