import SwiftUI
import VittoraCore

struct PaymentMethodPicker: View {
    @Binding var selectedMethod: PaymentMethod

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            // Standalone section heading, so it needs the same treatment as a
            // Form `header:` — VFormSectionHeader pins textPrimary and carries
            // the identifier the audit uses to recognise a header it has
            // mis-sampled. As a bare caption2 Text it was neither.
            VFormSectionHeader(String(localized: "Payment Method"))

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
                            // Control fill, NOT a card: these chips sit on an
                            // already-white surface, so they need the plain
                            // secondary grey to stay visible. The grouped
                            // token would make them white-on-white.
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
