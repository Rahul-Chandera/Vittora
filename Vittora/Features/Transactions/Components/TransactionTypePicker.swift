import SwiftUI

struct TransactionTypePicker: View {
    @Binding var type: TransactionType

    var body: some View {
        Picker("Type", selection: $type) {
            HStack {
                Image(systemName: "arrow.down")
                    .foregroundColor(VColors.expense)
                Text("Expense").tag(TransactionType.expense)
            }

            HStack {
                Image(systemName: "arrow.up")
                    .foregroundColor(VColors.income)
                Text("Income").tag(TransactionType.income)
            }

            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(VColors.transfer)
                Text("Transfer").tag(TransactionType.transfer)
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
