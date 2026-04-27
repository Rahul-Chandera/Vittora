import SwiftUI

struct PaymentMethodPicker: View {
    @Binding var selectedMethod: PaymentMethod

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Payment Method"))
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: VSpacing.md) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    Button {
                        selectedMethod = method
                    } label: {
                        VStack(spacing: VSpacing.sm) {
                            Image(systemName: methodIcon(for: method))
                                .font(.title2)
                                .foregroundColor(
                                    selectedMethod == method ? .white : VColors.primary
                                )

                            Text(methodLabel(for: method))
                                .font(VTypography.caption2)
                                .foregroundColor(
                                    selectedMethod == method ? .white : VColors.textPrimary
                                )
                                .adaptiveLineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(VSpacing.md)
                        .background(
                            selectedMethod == method ? VColors.primary : VColors.secondaryBackground
                        )
                        .cornerRadius(VSpacing.cornerRadiusSM)
                    }
                }
            }
        }
    }

    private func methodIcon(for method: PaymentMethod) -> String {
        switch method {
        case .cash:
            return "banknote"
        case .creditCard:
            return "creditcard"
        case .debitCard:
            return "creditcard.circle"
        case .bankTransfer:
            return "arrow.left.arrow.right.circle"
        case .upi:
            return "phone.circle"
        case .wallet:
            return "wallet.pass"
        case .other:
            return "ellipsis.circle"
        }
    }

    private func methodLabel(for method: PaymentMethod) -> String {
        switch method {
        case .cash:
            return String(localized: "Cash")
        case .creditCard:
            return String(localized: "Credit Card")
        case .debitCard:
            return String(localized: "Debit Card")
        case .bankTransfer:
            return String(localized: "Bank Transfer")
        case .upi:
            return String(localized: "UPI")
        case .wallet:
            return String(localized: "Wallet")
        case .other:
            return String(localized: "Other")
        }
    }
}

#Preview {
    PaymentMethodPicker(selectedMethod: .constant(.cash))
        .padding(VSpacing.lg)
        .background(VColors.background)
}
