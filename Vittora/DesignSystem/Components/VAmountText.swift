import SwiftUI
import VittoraCore

/// Displays currency-formatted amounts with semantic coloring and rounded font design.
/// Supports multiple sizes and automatic color coding based on transaction type.
struct VAmountText: View {
    let amount: Decimal
    let currencyCode: String
    let type: TransactionType
    let size: AmountSize

    enum TransactionType {
        case income
        case expense
        case neutral
        case auto // Automatically determine based on amount sign
    }

    enum AmountSize {
        case large
        case medium
        case small
        case caption
        case title3
        case title2
        case callout
        case body

        var font: Font {
            switch self {
            case .large: return VTypography.amountLarge
            case .medium: return VTypography.amountMedium
            case .small: return VTypography.amountSmall
            case .caption: return VTypography.amountCaption
            case .title3: return VTypography.title3
            case .title2: return VTypography.title2
            case .callout: return VTypography.callout
            case .body: return VTypography.body
            }
        }

        var lineHeight: CGFloat {
            switch self {
            case .large: return 38
            case .medium: return 28
            case .small: return 22
            case .caption: return 16
            case .title3: return 24
            case .title2: return 26
            case .callout: return 20
            case .body: return 20
            }
        }
    }

    init(
        _ amount: Decimal,
        currencyCode: String = CurrencyDefaults.code,
        type: TransactionType = .auto,
        size: AmountSize = .medium
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.type = type
        self.size = size
    }

    var body: some View {
        Text(formattedAmount)
            .font(size.font)
            .foregroundColor(amountColor)
            .adaptiveLineLimit(1)
            .adaptiveMinimumScaleFactor(0.9)
    }

    private var formattedAmount: String {
        // `.fractionLength(0...2)` here dropped trailing zeros, so money lost
        // its cents: a 150.00 budget with 101.50 spent read "$101.5" and
        // "$48.5", and 32.00 read "$32", next to correctly formatted values
        // like "$189.99" in the same card. Only amounts whose cents happen to
        // end in zero were affected, which is why it survived.
        //
        // The currency style's own default is right per currency — two places
        // for USD, none for JPY — so it is not overridden at all. This matches
        // `Decimal.formatted(currencyCode:)`, which the rest of the app uses.
        abs(amount).formatted(.currency(code: currencyCode))
    }

    private var amountColor: Color {
        switch type {
        case .income:
            return VColors.income
        case .expense:
            return VColors.expense
        case .neutral:
            return VColors.textPrimary
        case .auto:
            return amount >= 0 ? VColors.income : VColors.expense
        }
    }
}

// MARK: - Convenience Initializers
extension VAmountText {
    init(
        income amount: Decimal,
        currencyCode: String = CurrencyDefaults.code,
        size: AmountSize = .medium
    ) {
        self.init(amount, currencyCode: currencyCode, type: .income, size: size)
    }

    init(
        expense amount: Decimal,
        currencyCode: String = CurrencyDefaults.code,
        size: AmountSize = .medium
    ) {
        self.init(amount, currencyCode: currencyCode, type: .expense, size: size)
    }

    init(
        _ amount: Decimal,
        currencyCode: String = CurrencyDefaults.code,
        size: AmountSize = .medium
    ) {
        self.init(amount, currencyCode: currencyCode, type: .auto, size: size)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: VSpacing.xl) {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(verbatim: "Large Amounts")
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)
            HStack(spacing: VSpacing.xl) {
                VStack(alignment: .leading) {
                    Text("Income")
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.textSecondary)
                    VAmountText(income: 1250.50, size: .large)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("Expense")
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.textSecondary)
                    VAmountText(expense: 89.99, size: .large)
                }
            }
        }

        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(verbatim: "Medium Amounts")
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)
            HStack(spacing: VSpacing.xl) {
                VStack(alignment: .leading) {
                    Text(verbatim: "Auto (Positive)")
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.textSecondary)
                    VAmountText(500, size: .medium)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text(verbatim: "Auto (Negative)")
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.textSecondary)
                    VAmountText(-150, size: .medium)
                }
            }
        }

        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(verbatim: "Small & Caption Amounts")
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)
            HStack(spacing: VSpacing.xl) {
                VAmountText(225.75, size: .small)
                VAmountText(45.00, currencyCode: "GBP", size: .caption)
                VAmountText(1000000, currencyCode: "JPY", size: .small)
            }
        }

        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
