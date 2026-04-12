import SwiftUI

struct AccountPickerView: View {
    @Binding var selectedAccountID: UUID?
    let accounts: [AccountEntity]
    var excludeID: UUID? = nil
    var title: String = "Select Account"

    var filteredAccounts: [AccountEntity] {
        accounts.filter { $0.id != excludeID && !$0.isArchived }
    }

    var body: some View {
        List(filteredAccounts) { account in
            Button {
                selectedAccountID = account.id
            } label: {
                HStack {
                    AccountRowView(account: account)
                    Spacer()
                    if selectedAccountID == account.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(VColors.primary)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        AccountPickerView(
            selectedAccountID: .constant(nil),
            accounts: [
                AccountEntity(name: "Chase Checking", type: .bank, balance: 3450),
                AccountEntity(name: "Visa Card", type: .creditCard, balance: -1200),
                AccountEntity(name: "Cash", type: .cash, balance: 85)
            ]
        )
    }
}
