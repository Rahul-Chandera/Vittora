import SwiftUI

struct TransactionTypePicker: View {
    @Binding var type: TransactionType

    var body: some View {
        Picker(String(localized: "Type"), selection: $type) {
            HStack {
                Image(systemName: "arrow.down")
                    .foregroundColor(VColors.expense)
                    .accessibilityHidden(true)
                Text(String(localized: "Expense")).tag(TransactionType.expense)
            }

            HStack {
                Image(systemName: "arrow.up")
                    .foregroundColor(VColors.income)
                    .accessibilityHidden(true)
                Text(String(localized: "Income")).tag(TransactionType.income)
            }

            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(VColors.transfer)
                    .accessibilityHidden(true)
                Text(String(localized: "Transfer")).tag(TransactionType.transfer)
            }
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    Form {
        TransactionTypePicker(type: .constant(.expense))
    }
}
