import SwiftUI

struct ReceiptReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: ReceiptReviewViewModel
    let onCreateTransaction: (Decimal, String, Date) -> Void

    init(
        receiptData: ReceiptData,
        onCreateTransaction: @escaping (Decimal, String, Date) -> Void
    ) {
        _vm = State(initialValue: ReceiptReviewViewModel(receiptData: receiptData))
        self.onCreateTransaction = onCreateTransaction
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VSpacing.sectionSpacing) {
                    // Extracted fields
                    VStack(alignment: .leading, spacing: VSpacing.md) {
                        Text(String(localized: "Extracted Information"))
                            .font(VTypography.subheadline)
                            .foregroundColor(VColors.textSecondary)

                        ExtractedFieldRow(
                            label: String(localized: "Merchant"),
                            value: Bindable(vm).merchantName,
                            confidence: nil,
                            keyboardType: .text
                        )

                        ExtractedFieldRow(
                            label: String(localized: "Amount"),
                            value: Bindable(vm).amountString,
                            confidence: nil,
                            keyboardType: .number
                        )

                        ExtractedFieldRow(
                            label: String(localized: "Date (MM/DD/YYYY)"),
                            value: Bindable(vm).dateString,
                            confidence: nil,
                            keyboardType: .date
                        )
                    }

                    // Raw text preview
                    if !vm.rawText.isEmpty {
                        VStack(alignment: .leading, spacing: VSpacing.sm) {
                            Text(String(localized: "Raw Text"))
                                .font(VTypography.subheadline)
                                .foregroundColor(VColors.textSecondary)

                            ScrollView {
                                Text(vm.rawText)
                                    .font(VTypography.caption2)
                                    .foregroundColor(VColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(VSpacing.md)
                            }
                            .frame(maxHeight: 120)
                            .background(VColors.secondaryBackground)
                            .cornerRadius(VSpacing.cornerRadiusMD)
                        }
                    }
                }
                .padding(VSpacing.screenPadding)
            }
            .background(VColors.background)
            .navigationTitle(String(localized: "Review Receipt"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Create Transaction")) {
                        let prefill = vm.buildPrefilledTransaction()
                        onCreateTransaction(prefill.amount, prefill.note, prefill.date)
                        dismiss()
                    }
                    .disabled(!vm.isValid)
                }
            }
        }
    }
}

#Preview {
    ReceiptReviewView(
        receiptData: ReceiptData(
            totalAmount: 24.99,
            date: .now,
            merchantName: "Coffee Shop",
            lineItems: [],
            rawText: "Coffee Shop\n12/25/2024\nTotal: $24.99"
        ),
        onCreateTransaction: { _, _, _ in }
    )
}
