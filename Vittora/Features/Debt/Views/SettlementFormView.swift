import SwiftUI
import VittoraCore

struct SettlementFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.currencySymbol) private var currencySymbol
    let debt: DebtEntry
    let onSettled: () -> Void

    @State private var amountString: String = ""
    @State private var selectedAccountID: UUID?
    @State private var accounts: [AccountEntity] = []
    @State private var isLoading = false
    @State private var error: String?

    private var amount: Decimal? { Decimal(localizedAmount: amountString) }
    private var maxAmount: Decimal { debt.remainingAmount }
    private var canSettle: Bool { (amount ?? 0) > 0 && (amount ?? 0) <= maxAmount }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(currencySymbol)
                            .foregroundColor(VColors.textPrimary)
                            .accessibilityHidden(true)
                        TextField(
                            "",
                            text: $amountString,
                            prompt: Text(String(localized: "Amount"))
                                .foregroundStyle(VColors.placeholderText)
                        )
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .textContentType(nil)
                            #endif
                            .accessibilityLabel(String(localized: "Settlement amount"))
                            .accessibilityHint(String(localized: "Amount in \(currencyCode)"))
                    }
                    Button(String(localized: "Settle Full Amount (\(CurrencyFormatter.format(maxAmount, currencyCode: currencyCode)))")) {
                        amountString = "\(maxAmount)"
                    }
                    .font(VTypography.body)
                    .foregroundColor(VColors.textPrimary)
                } header: {
                    sectionHeader(String(localized: "Settlement Amount"))
                }
                .headerProminence(.increased)

                Section {
                    Picker(String(localized: "Account"), selection: $selectedAccountID) {
                        Text(String(localized: "None")).tag(UUID?.none)
                        ForEach(accounts) { account in
                            Text(account.name).tag(UUID?(account.id))
                        }
                    }
                } header: {
                    sectionHeader(String(localized: "Record to Account (optional)"))
                }
                .headerProminence(.increased)

                if let errorMessage = error {
                    Section {
                        VInlineErrorText(errorMessage)
                    }
                }
            }
            .tint(VColors.textPrimary)
            .navigationTitle(String(localized: "Settle Debt"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                            .vDialogCancelButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Settle")) {
                        guard canSettle, !isLoading else { return }
                        Task { await settle() }
                    }
                    .font(.headline)
                    .accessibilityRespondsToUserInteraction(canSettle && !isLoading)
                    .foregroundStyle(.primary)
                    .vDialogConfirmButton()
                }
            }
        }
        .task {
            do {
                accounts = try await dependencies.accountRepository.fetchAll()
            } catch {
                self.error = error.localizedDescription
            }
        }
        .onChange(of: error) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        VFormSectionHeader(title)
    }

    private func settle() async {
        guard let amount else { return }
        isLoading = true
        error = nil
        let useCase = SettleDebtUseCase(
            debtRepository: dependencies.debtRepository,
            accountRepository: dependencies.accountRepository,
            ledgerWriting: dependencies.ledgerWriteStore
        )
        do {
            try await useCase.execute(
                debtID: debt.id,
                settlementAmount: amount,
                accountID: selectedAccountID
            )
            await dependencies.refreshRecurringAndDebtReminders()
            // .budgets too: settling writes a transaction, so a budget
            // covering its category is now stale.
            appState.notifyChanged([.debt, .transactions, .accounts, .budgets])
            onSettled()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
