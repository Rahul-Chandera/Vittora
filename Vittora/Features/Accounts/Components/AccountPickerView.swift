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
    /// Called after a new account is created from the empty state, so the host
    /// can reload the `accounts` it passed in — this view only receives them.
    var onAccountCreated: (() -> Void)? = nil

    @State private var showAddAccount = false

    var filteredAccounts: [AccountEntity] {
        accounts.filter { $0.id != excludeID && !$0.isArchived }
    }

    var body: some View {
        Group {
            if filteredAccounts.isEmpty {
                emptyState
            } else {
                accountList
            }
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
        .toolbar {
            // Also reachable when the list is NOT empty — matches the payee
            // picker, so both behave the same way.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddAccount = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Add Account"))
                .accessibilityIdentifier("account-picker-add-button")
            }
        }
        .sheet(isPresented: $showAddAccount) {
            NavigationStack {
                AccountFormView(showsCancelButton: true) {
                    onAccountCreated?()
                }
            }
        }
    }

    /// Distinguishes "no accounts at all" from "no OTHER account", which is the
    /// case that rendered blank: a transfer excludes the source account, so the
    /// only account was filtered out and the List had nothing to draw.
    private var emptyState: some View {
        VEmptyState(
            icon: "building.columns",
            title: excludeID == nil
                ? String(localized: "No Accounts Yet")
                : String(localized: "No Other Accounts"),
            subtitle: excludeID == nil
                ? String(localized: "Add an account to continue")
                : String(localized: "A transfer needs a second account. Add one to continue."),
            actionLabel: String(localized: "Add Account"),
            action: { showAddAccount = true }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VColors.groupedBackground)
        .accessibilityIdentifier("account-picker-empty-state")
    }

    private var accountList: some View {
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
