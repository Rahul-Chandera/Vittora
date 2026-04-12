import SwiftUI

/// A pill-shaped badge displaying category icon and name.
/// Features semantic coloring and configurable sizes.
struct VCategoryBadge: View {
    let iconName: String
    let categoryName: String
    let categoryColor: Color
    let size: BadgeSize

    enum BadgeSize {
        case compact
        case regular

        var horizontalPadding: CGFloat {
            switch self {
            case .compact: return VSpacing.sm
            case .regular: return VSpacing.md
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .compact: return VSpacing.xs
            case .regular: return VSpacing.sm
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .compact: return 14
            case .regular: return 16
            }
        }

        var fontSize: Font {
            switch self {
            case .compact: return VTypography.caption2
            case .regular: return VTypography.caption1
            }
        }
    }

    init(
        icon: String,
        name: String,
        color: Color,
        size: BadgeSize = .regular
    ) {
        self.iconName = icon
        self.categoryName = name
        self.categoryColor = color
        self.size = size
    }

    var body: some View {
        HStack(spacing: VSpacing.xs) {
            Image(systemName: iconName)
                .font(.system(size: size.iconSize, weight: .semibold))
            Text(categoryName)
                .font(size.fontSize)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .foregroundColor(.white)
        .background(categoryColor)
        .cornerRadius(VSpacing.cornerRadiusPill)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: VSpacing.lg) {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text("Regular Size")
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)
            HStack(spacing: VSpacing.md) {
                VCategoryBadge(
                    icon: VIcons.CategoryIcons.shopping,
                    name: "Shopping",
                    color: .blue,
                    size: .regular
                )
                VCategoryBadge(
                    icon: VIcons.CategoryIcons.food,
                    name: "Dining",
                    color: .orange,
                    size: .regular
                )
                VCategoryBadge(
                    icon: VIcons.CategoryIcons.transport,
                    name: "Transport",
                    color: .green,
                    size: .regular
                )
                Spacer()
            }
        }

        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text("Compact Size")
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)
            HStack(spacing: VSpacing.md) {
                VCategoryBadge(
                    icon: VIcons.CategoryIcons.health,
                    name: "Health",
                    color: .red,
                    size: .compact
                )
                VCategoryBadge(
                    icon: VIcons.CategoryIcons.entertainment,
                    name: "Movies",
                    color: .purple,
                    size: .compact
                )
                VCategoryBadge(
                    icon: VIcons.CategoryIcons.education,
                    name: "Learning",
                    color: .indigo,
                    size: .compact
                )
                Spacer()
            }
        }

        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text("Various Colors")
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)
            Wrap(spacing: VSpacing.md, lineSpacing: VSpacing.md) {
                VCategoryBadge(
                    icon: VIcons.CategoryIcons.salary,
                    name: "Salary",
                    color: VColors.income,
                    size: .regular
                )
                VCategoryBadge(
                    icon: VIcons.CategoryIcons.shopping,
                    name: "Shopping",
                    color: VColors.expense,
                    size: .regular
                )
                VCategoryBadge(
                    icon: VIcons.CategoryIcons.investment,
                    name: "Investment",
                    color: .teal,
                    size: .regular
                )
                VCategoryBadge(
                    icon: VIcons.CategoryIcons.gifts,
                    name: "Gifts",
                    color: .pink,
                    size: .regular
                )
            }
        }

        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}

// Simple wrapping layout for preview
fileprivate struct Wrap<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content()
    }

    var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(0..<10, id: \.self) { _ in
                content
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > 200 {
                            width = 0
                            height -= (d.height + lineSpacing)
                        }
                        let result = width
                        width -= d.width
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        return result
                    }
            }
        }
    }
}
