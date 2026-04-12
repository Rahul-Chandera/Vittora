import SwiftUI

struct AccountListView: View {
    @Environment(\.dependencies) private var dependencies
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
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddAccount = true
                } label: {
                    Image(systemName: VIcons.Actions.add)
                }
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
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let id = accountToDelete, let vm = viewModel {
                    Task { await vm.deleteAccount(id: id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this account? This action cannot be undone.")
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
            Text("No Accounts")
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)
            Text("Add your first account to start tracking your finances.")
                .font(VTypography.body)
                .foregroundColor(VColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Add Account") { showAddAccount = true }
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
                    totalLiabilities: vm.totalLiabilities
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
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    Task { await vm.archiveAccount(id: account.id) }
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
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
        case .cash: return "Cash"
        case .bank: return "Bank Accounts"
        case .creditCard: return "Credit Cards"
        case .loan: return "Loans"
        case .digitalWallet: return "Digital Wallets"
        case .investment: return "Investments"
        case .receivable: return "Receivables"
        case .payable: return "Payables"
        }
    }
}

#Preview {
    NavigationStack {
        AccountListView()
    }
}
