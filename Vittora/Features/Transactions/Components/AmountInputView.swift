import SwiftUI

struct AmountInputView: View {
    @Binding var amountString: String
    var currencyCode: String = "USD"
    var type: TransactionType = .expense
    var textFieldAccessibilityIdentifier: String?

    var body: some View {
        VStack(spacing: VSpacing.md) {
            HStack(spacing: VSpacing.xs) {
                Text(String.currencySymbol(for: currencyCode))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(transactionColor(for: type))

                TextField(String(localized: "0.00"), text: $amountString)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(transactionColor(for: type))
                    .accessibilityIdentifier(textFieldAccessibilityIdentifier ?? "")
                    #if os(iOS)
                    .keyboardType(.decimalPad)
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

                Spacer()
            }
            .padding(VSpacing.lg)
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusSM)
        }
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
