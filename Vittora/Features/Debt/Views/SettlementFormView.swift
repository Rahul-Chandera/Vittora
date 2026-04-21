import SwiftUI

struct SettlementFormView: View {
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

    private var amount: Decimal? { Decimal(string: amountString) }
    private var maxAmount: Decimal { debt.remainingAmount }
    private var canSettle: Bool { (amount ?? 0) > 0 && (amount ?? 0) <= maxAmount }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Settlement Amount")) {
                    HStack {
                        Text(currencySymbol).foregroundColor(VColors.textSecondary)
                        TextField(String(localized: "Amount"), text: $amountString)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .textContentType(nil)
                            #endif
                    }
                    Button(String(localized: "Settle Full Amount (\(formattedAmount(maxAmount)))")) {
                        amountString = "\(maxAmount)"
                    }
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.primary)
                }

                Section(String(localized: "Record to Account (optional)")) {
                    Picker(String(localized: "Account"), selection: $selectedAccountID) {
                        Text(String(localized: "None")).tag(UUID?.none)
                        ForEach(accounts) { account in
                            Text(account.name).tag(UUID?(account.id))
                        }
                    }
                }

                if let errorMessage = error {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(VColors.expense)
                            .font(VTypography.caption1)
                    }
                }
            }
            .navigationTitle(String(localized: "Settle Debt"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Settle")) {
                        Task { await settle() }
                    }
                    .disabled(!canSettle || isLoading)
                }
            }
        }
        .task {
            do {
                accounts = try await dependencies.accountRepository?.fetchAll() ?? []
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

    private func settle() async {
        guard let amount,
              let debtRepo = dependencies.debtRepository,
              let txRepo = dependencies.transactionRepository,
              let accRepo = dependencies.accountRepository else { return }
        isLoading = true
        error = nil
        let useCase = SettleDebtUseCase(
            debtRepository: debtRepo,
            transactionRepository: txRepo,
            accountRepository: accRepo
        )
        do {
            try await useCase.execute(
                debtID: debt.id,
                settlementAmount: amount,
                accountID: selectedAccountID
            )
            onSettled()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        amount.formatted(currencyCode: currencyCode)
    }
}
