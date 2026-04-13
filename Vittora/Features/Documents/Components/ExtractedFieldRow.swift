import SwiftUI

struct ExtractedFieldRow: View {
    let label: String
    @Binding var value: String
    let confidence: Float?
    let keyboardType: KeyboardTypeHint

    enum KeyboardTypeHint {
        case text, number, date
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            HStack(spacing: VSpacing.sm) {
                Text(label)
                    .font(VTypography.caption2)
                    .foregroundColor(VColors.textSecondary)

                if let confidence = confidence {
                    confidenceBadge(confidence)
                }
            }

            TextField(label, text: $value)
                .font(VTypography.body)
                .foregroundColor(VColors.textPrimary)
                #if os(iOS)
                .keyboardType(platformKeyboardType)
                #endif
        }
        .padding(VSpacing.md)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusMD)
    }

    @ViewBuilder
    private func confidenceBadge(_ confidence: Float) -> some View {
        let isHigh = confidence > 0.8
        Text(isHigh ? String(localized: "High") : String(localized: "Low"))
            .font(VTypography.caption2)
            .foregroundColor(isHigh ? VColors.income : VColors.warning)
            .padding(.horizontal, VSpacing.xs)
            .padding(.vertical, VSpacing.xxs)
            .background((isHigh ? VColors.income : VColors.warning).opacity(0.12))
            .cornerRadius(VSpacing.cornerRadiusPill)
    }

    #if os(iOS)
    private var platformKeyboardType: UIKeyboardType {
        switch keyboardType {
        case .text:   return .default
        case .number: return .decimalPad
        case .date:   return .numbersAndPunctuation
        }
    }
    #endif
}

#Preview {
    VStack(spacing: VSpacing.md) {
        ExtractedFieldRow(
            label: "Merchant",
            value: .constant("Starbucks"),
            confidence: 0.95,
            keyboardType: .text
        )
        ExtractedFieldRow(
            label: "Amount",
            value: .constant("12.50"),
            confidence: 0.72,
            keyboardType: .number
        )
    }
    .padding()
}
