import SwiftUI
import VittoraCore

struct AmountInputView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var amountString: String
    var currencyCode: String = CurrencyDefaults.code
    var type: TransactionType = .expense
    var textFieldAccessibilityIdentifier: String?
    /// Raise the keyboard as the screen appears. Opt-in: it is right when the
    /// user came here to type an amount, wrong when they came to read one.
    var autoFocus: Bool = false

    @FocusState private var isAmountFocused: Bool

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
                        // The caret, not the text. A tint set on the enclosing
                        // Form does not reach this field's insertion point on
                        // macOS — measured white-on-grey at about 1.1:1, so
                        // there was no visible cursor at all.
                        // The caret. `.tint` does drive it — a probe with red
                        // turned it red — but textPrimary resolved white here.
                        // See VColors.textCursor for why.
                        .tint(VColors.textCursor)
                        .accessibilityLabel(String(localized: "Amount"))
                        .accessibilityValue(amountAccessibilityValue)
                        .accessibilityIdentifier(textFieldAccessibilityIdentifier ?? "")
                        .focused($isAmountFocused)
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
        .task { await focusAmountIfRequested() }
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

    @MainActor
    private func focusAmountIfRequested() async {
        guard autoFocus else { return }
        // A beat after appearing. Focus set while the sheet is still animating
        // in is discarded, and the keyboard never comes up.
        try? await Task.sleep(for: .milliseconds(350))
        isAmountFocused = true
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
            // On-surface, not the fill: this colours the amount TEXT and the
            // type label on a card. The fill accent is solved to carry white
            // content on top of it, and with the purple accent on the OLED
            // card it measures 3.35:1 against the 4.5:1 body-text minimum.
            return VColors.primaryOnSurface
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
