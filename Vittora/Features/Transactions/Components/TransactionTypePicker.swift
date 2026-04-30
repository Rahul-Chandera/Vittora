import SwiftUI

struct TransactionTypePicker: View {
    @Binding var type: TransactionType

    var body: some View {
        Picker(String(localized: "Type"), selection: $type) {
            Text(String(localized: "Expense"))
                .tag(TransactionType.expense)

            Text(String(localized: "Income"))
                .tag(TransactionType.income)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("transaction-type-picker-control")
    }
}

#Preview {
    Form {
        TransactionTypePicker(type: .constant(.expense))
    }
}
