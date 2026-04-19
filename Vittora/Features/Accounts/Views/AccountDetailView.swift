import SwiftUI

struct AccountDetailView: View {
    let accountID: UUID
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var viewModel: AccountDetailViewModel?
    @State private var showEditSheet = false

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel?.account?.name ?? "Account")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Edit")) { showEditSheet = true }
                    .disabled(viewModel?.account == nil)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let account = viewModel?.account {
                NavigationStack {
                    AccountFormView(editingAccount: account) {
                        Task { await viewModel?.loadAccount(id: accountID) }
                    }
                }
            }
        }
        .task {
            await setupViewModel()
        }
    }

    @MainActor
    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let deps = dependencies
        guard let accountRepo = deps.accountRepository,
              let transactionRepo = deps.transactionRepository else { return }

        let vm = AccountDetailViewModel(
            accountRepository: accountRepo,
            transactionRepository: transactionRepo
        )
        viewModel = vm
        await vm.loadAccount(id: accountID)
    }

    @ViewBuilder
    private func content(vm: AccountDetailViewModel) -> some View {
        if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let account = vm.account {
            accountDetail(account: account, vm: vm)
        } else {
            Text(String(localized: "Account not found"))
                .foregroundColor(VColors.textSecondary)
        }
    }

    @ViewBuilder
    private func accountDetail(account: AccountEntity, vm: AccountDetailViewModel) -> some View {
        List {
            // Balance Card
            Section {
                VCard(padding: VSpacing.lg, shadow: .medium) {
                    VStack(alignment: .leading, spacing: VSpacing.sm) {
                        HStack {
                            AccountTypeIcon(type: account.type, size: 48)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(account.type.rawValue.capitalized)
                                    .font(VTypography.caption1)
                                    .foregroundColor(VColors.textSecondary)
                                Text(account.currencyCode)
                                    .font(VTypography.caption2)
                                    .foregroundColor(VColors.textTertiary)
                            }
                        }
                        Text(String(localized: "Current Balance"))
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.textSecondary)
                        Text(account.balance.formatted(.currency(code: account.currencyCode)))
                            .font(VTypography.amountLarge)
                            .foregroundColor(account.balance >= 0 ? VColors.textPrimary : VColors.expense)
                    }
                }
                .listRowInsets(EdgeInsets(top: VSpacing.sm, leading: VSpacing.screenPadding, bottom: VSpacing.sm, trailing: VSpacing.screenPadding))
                .listRowBackground(Color.clear)
            }

            // Account Details
            Section(String(localized: "Details")) {
                LabeledContent("Name", value: account.name)
                LabeledContent("Type", value: account.type.rawValue.capitalized)
                LabeledContent("Currency", value: account.currencyCode)
                LabeledContent("Created", value: account.createdAt.formatted(date: .abbreviated, time: .omitted))
                if account.isArchived {
                    LabeledContent("Status") {
                        Text(String(localized: "Archived"))
                            .foregroundColor(VColors.textTertiary)
                    }
                }
            }

            // Recent Transactions
            if !vm.recentTransactions.isEmpty {
                Section(String(localized: "Recent Transactions")) {
                    ForEach(vm.recentTransactions) { tx in
                        NavigationLink(value: NavigationDestination.transactionDetail(id: tx.id)) {
                            TransactionRowCell(transaction: tx)
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .refreshable { await vm.loadAccount(id: accountID) }
    }
}

// MARK: - Simple transaction row for reuse
private struct TransactionRowCell: View {
    let transaction: TransactionEntity
    @Environment(\.currencyCode) private var currencyCode

    var body: some View {
        HStack(spacing: VSpacing.sm) {
            VStack(alignment: .leading, spacing: VSpacing.xxs) {
                Text(transaction.note ?? "Transaction")
                    .font(VTypography.body)
                    .foregroundColor(VColors.textPrimary)
                    .adaptiveLineLimit(1)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
            }
            Spacer()
            Text(transaction.amount.formatted(.currency(code: currencyCode)))
                .font(VTypography.bodyBold)
                .foregroundColor(transaction.type == .income ? VColors.income : VColors.expense)
        }
        .padding(.vertical, VSpacing.xxs)
    }
}

#Preview {
    NavigationStack {
        AccountDetailView(accountID: UUID())
    }
}
