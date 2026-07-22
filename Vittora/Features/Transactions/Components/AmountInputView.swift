import SwiftUI
import VittoraCore

struct AmountInputView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var amountString: String
    var currencyCode: String = CurrencyDefaults.code
    var type: TransactionType = .expense
    var textFieldAccessibilityIdentifier: String?

    var body: some View {
        VStack(spacing: VSpacing.md) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.xs))
                : AnyLayout(HStackLayout(spacing: VSpacing.xs))
            layout {
                Text(String.currencySymbol(for: currencyCode))
                    .font(VTypography.amountLarge)
                    .foregroundColor(transactionColor(for: type))
                    .accessibilityHidden(true)

                // System TextField placeholder gray fails AA on secondaryBackground (~1.5:1).
                // Draw the empty prompt ourselves with the WCAG text token.
                ZStack(alignment: .leading) {
                    if amountString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(String(localized: "0.00"))
                            .font(VTypography.amountLarge)
                            .foregroundStyle(VColors.textPrimary)
                            .accessibilityHidden(true)
                    }
                    TextField("", text: $amountString)
                        .font(VTypography.amountLarge)
                        .foregroundColor(transactionColor(for: type))
                        .accessibilityLabel(String(localized: "Amount"))
                        .accessibilityValue(amountAccessibilityValue)
                        .accessibilityIdentifier(textFieldAccessibilityIdentifier ?? "")
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        .textContentType(nil)
                        #elseif os(macOS)
                        .textFieldStyle(.plain)
                        #endif
                        .onChange(of: amountString) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber || $0 == "." }
                            if filtered != newValue {
                                amountString = filtered
                            }
                            // Allow max 2 decimal places
                            let parts = filtered.split(separator: ".")
                            if parts.count > 2 {
                                amountString = String(filtered.dropLast())
                            } else if let decimalPart = parts.last, parts.count == 2, decimalPart.count > 2 {
                                amountString = String(filtered.dropLast())
                            }
                        }
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }
            }
            .padding(VSpacing.lg)
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusSM)
        }
    }

    private var amountAccessibilityValue: String {
        let trimmed = amountString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return String(localized: "Empty")
        }
        guard let amount = Decimal(string: trimmed) else {
            return trimmed
        }
        return CurrencyFormatter.format(amount, currencyCode: currencyCode)
    }

    private func transactionColor(for type: TransactionType) -> Color {
        switch type {
        case .expense:
            return VColors.expense
        case .income:
            return VColors.income
        case .transfer:
            return VColors.transfer
        case .adjustment:
            return VColors.primary
        }
    }
}

#Preview {
    VStack(spacing: VSpacing.lg) {
        AmountInputView(
            amountString: .constant("150.50"),
            currencyCode: "USD",
            type: .expense
        )

        AmountInputView(
            amountString: .constant("1500"),
            currencyCode: "USD",
            type: .income
        )
    }
    .padding(VSpacing.lg)
    .background(VColors.background)
}
