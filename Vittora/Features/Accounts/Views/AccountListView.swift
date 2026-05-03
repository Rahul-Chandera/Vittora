import SwiftUI

struct AccountListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var viewModel: AccountListViewModel?
    @State private var showAddAccount = false
    @State private var showingDeleteAlert = false
    @State private var accountToDelete: UUID?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "Accounts"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddAccount = true
                } label: {
                    Image(systemName: VIcons.Actions.add)
                }
                .accessibilityIdentifier("account-add-button")
                .accessibilityLabel(String(localized: "Add account"))
                .accessibilityHint(String(localized: "Opens the account form"))
            }
        }
        .sheet(isPresented: $showAddAccount) {
            if let vm = viewModel {
                NavigationStack {
                    AccountFormView(onSave: {
                        Task { await vm.loadAccounts() }
                    })
                }
            }
        }
        .alert(String(localized: "Delete Account"), isPresented: $showingDeleteAlert) {
            Button(String(localized: "Delete"), role: .destructive) {
                if let id = accountToDelete, let vm = viewModel {
                    Task {
                        await vm.deleteAccount(id: id)
                        appState.notifyDataChanged()
                    }
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "Are you sure you want to delete this account? This action cannot be undone."))
        }
        .task {
            await setupViewModel()
        }
        .task(id: appState.dataRefreshVersion) {
            guard viewModel != nil, appState.dataRefreshVersion > 0 else { return }
            await viewModel?.loadAccounts()
        }
    }

    @MainActor
    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let deps = dependencies
        guard let accountRepo = deps.accountRepository,
              let transactionRepo = deps.transactionRepository else { return }

        let fetchUseCase = FetchAccountsUseCase(accountRepository: accountRepo)
        let calcUseCase = CalculateNetWorthUseCase(accountRepository: accountRepo)
        let deleteUseCase = DeleteAccountUseCase(
            accountRepository: accountRepo,
            transactionRepository: transactionRepo
        )

        let vm = AccountListViewModel(
            fetchAccountsUseCase: fetchUseCase,
            calculateNetWorthUseCase: calcUseCase,
            deleteAccountUseCase: deleteUseCase
        )
        viewModel = vm
        await vm.loadAccounts()
    }

    @ViewBuilder
    private func content(vm: AccountListViewModel) -> some View {
        if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.accounts.isEmpty {
            emptyState
        } else {
            accountList(vm: vm)
        }
    }

    private var emptyState: some View {
        VStack(spacing: VSpacing.md) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 48))
                .foregroundColor(VColors.textTertiary)
            Text(String(localized: "No Accounts"))
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)
            Text(String(localized: "Add your first account to start tracking your finances."))
                .font(VTypography.body)
                .foregroundColor(VColors.textSecondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "Add Account")) { showAddAccount = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(VSpacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func accountList(vm: AccountListViewModel) -> some View {
        List {
            // Net Worth card
            Section {
                NetWorthCard(
                    netWorth: vm.netWorth,
                    totalAssets: vm.totalAssets,
                    totalLiabilities: vm.totalLiabilities,
                    currencyCode: currencyCode
                )
                .listRowInsets(EdgeInsets(
                    top: VSpacing.sm,
                    leading: VSpacing.screenPadding,
                    bottom: VSpacing.sm,
                    trailing: VSpacing.screenPadding
                ))
                .listRowBackground(Color.clear)
            }

            // Accounts grouped by type
            ForEach(AccountType.allCases, id: \.self) { type in
                let accountsForType = vm.groupedAccounts[type] ?? []
                if !accountsForType.isEmpty {
                    Section(header: Text(sectionTitle(for: type))) {
                        ForEach(accountsForType) { account in
                            NavigationLink(value: NavigationDestination.accountDetail(id: account.id)) {
                                AccountRowView(account: account)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    accountToDelete = account.id
                                    showingDeleteAlert = true
                                } label: {
                                    Label(String(localized: "Delete"), systemImage: "trash")
                                }
                                Button {
                                    Task {
                                        await vm.archiveAccount(id: account.id)
                                        appState.notifyDataChanged()
                                    }
                                } label: {
                                    Label(String(localized: "Archive"), systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
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
        .refreshable { await vm.loadAccounts() }
        .overlay {
            if let error = vm.error {
                VStack {
                    Spacer()
                    Text(error)
                        .font(VTypography.caption1)
                        .foregroundColor(.white)
                        .padding(VSpacing.md)
                        .background(VColors.expense)
                        .cornerRadius(VSpacing.cornerRadiusCard)
                        .padding(VSpacing.screenPadding)
                }
            }
        }
    }

    private func sectionTitle(for type: AccountType) -> String {
        switch type {
        case .cash: return String(localized: "Cash")
        case .bank: return String(localized: "Bank Accounts")
        case .creditCard: return String(localized: "Credit Cards")
        case .loan: return String(localized: "Loans")
        case .digitalWallet: return String(localized: "Digital Wallets")
        case .investment: return String(localized: "Investments")
        case .receivable: return String(localized: "Receivables")
        case .payable: return String(localized: "Payables")
        }
    }
}

#Preview {
    NavigationStack {
        AccountListView()
    }
}
