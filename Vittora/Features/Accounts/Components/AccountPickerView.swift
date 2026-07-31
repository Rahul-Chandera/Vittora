import Foundation
import SwiftUI
import VittoraCore

struct AccountPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAccountID: UUID?
    let accounts: [AccountEntity]
    var excludeID: UUID? = nil
    var title: String = "Select Account"
    var accessibilityIdentifierPrefix: String = "account-picker-row"
    var dismissOnSelection: Bool = false

    var filteredAccounts: [AccountEntity] {
        accounts.filter { $0.id != excludeID && !$0.isArchived }
    }

    var body: some View {
        List(filteredAccounts) { account in
            Button {
                selectedAccountID = account.id
                if dismissOnSelection {
                    dismiss()
                }
            } label: {
                HStack {
                    AccountRowView(account: account)
                    Spacer()
                    if selectedAccountID == account.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(VColors.primaryOnSurface)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("\(accessibilityIdentifierPrefix)-\(sanitizedIdentifier(for: account.name))")
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #else
        // macOS sheets resize to the pushed view's ideal size; List reports a
        // near-zero ideal height, collapsing the sheet without an explicit min.
        .frame(minWidth: 440, minHeight: 480)
        #endif
        .accessibilityIdentifier("account-picker-root")
    }

    private func sanitizedIdentifier(for name: String) -> String {
        let lowered = name.lowercased()
        var result = ""
        var lastWasSeparator = false

        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                result.append("-")
                lastWasSeparator = true
            }
        }

        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
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
