import SwiftUI

struct DebtLedgerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @State private var vm: DebtLedgerViewModel?
    @State private var showAddDebt = false
    @State private var selectedPayeeID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                if let vm = vm {
                    if vm.isLoading && vm.ledgerEntries.isEmpty {
                        ProgressView().tint(VColors.primary)
                    } else if let error = vm.error {
                        ContentUnavailableView {
                            Label(String(localized: "Unable to Load"), systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(error)
                        } actions: {
                            Button(String(localized: "Try Again")) {
                                vm.error = nil
                                Task { await vm.load() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(VColors.primary)
                        }
                    } else {
                        ledgerContent(vm)
                    }
                }
            }
            .background(VColors.background)
            .navigationTitle(String(localized: "Debt Ledger"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddDebt = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(item: $selectedPayeeID) { payeeID in
                DebtDetailView(payeeID: payeeID)
            }
        }
        .task {
            if vm == nil {
                guard let debtRepo = dependencies.debtRepository,
                      let payeeRepo = dependencies.payeeRepository else { return }
                vm = DebtLedgerViewModel(
                    fetchLedgerUseCase: FetchDebtLedgerUseCase(
                        debtRepository: debtRepo,
                        payeeRepository: payeeRepo
                    ),
                    calculateBalanceUseCase: CalculateDebtBalanceUseCase(debtRepository: debtRepo),
                    fetchOverdueUseCase: FetchOverdueDebtsUseCase(debtRepository: debtRepo)
                )
                await vm?.load()
            }
        }
        .task(id: appState.dataRefreshVersion) {
            guard vm != nil, appState.dataRefreshVersion > 0 else { return }
            await vm?.load()
        }
        .sheet(isPresented: $showAddDebt) {
            DebtFormView {
                Task { await vm?.load() }
            }
        }
        .refreshable {
            await vm?.load()
        }
    }

    @ViewBuilder
    private func ledgerContent(_ vm: DebtLedgerViewModel) -> some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let balance = vm.balance {
                    DebtSummaryCard(balance: balance)
                }

                if !vm.overdueEntries.isEmpty {
                    overdueBanner(vm.overdueEntries.count)
                }

                if vm.ledgerEntries.isEmpty {
                    emptyState
                } else {
                    if !vm.owedToMeEntries.isEmpty {
                        section(title: String(localized: "Owed to You"), entries: vm.owedToMeEntries)
                    }
                    if !vm.iOweEntries.isEmpty {
                        section(title: String(localized: "You Owe"), entries: vm.iOweEntries)
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
    }

    @ViewBuilder
    private func section(title: String, entries: [DebtLedgerEntry]) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(title)
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    Button {
                        selectedPayeeID = entry.payee.id
                    } label: {
                        DebtRowView(entry: entry)
                            .padding(.horizontal, VSpacing.md)
                    }
                    .buttonStyle(.plain)

                    if entry.id != entries.last?.id {
                        Divider().padding(.leading, VSpacing.lg)
                    }
                }
            }
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
    }

    private func overdueBanner(_ count: Int) -> some View {
        HStack(spacing: VSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(String(localized: "\(count) overdue debt(s)"))
                .font(VTypography.caption1Bold)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(VSpacing.md)
        .background(VColors.expense)
        .cornerRadius(VSpacing.cornerRadiusMD)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(String(localized: "No debts recorded"), systemImage: "person.2.slash")
        } description: {
            Text(String(localized: "Track money you lent or borrowed"))
        } actions: {
            Button(String(localized: "Add Entry")) {
                showAddDebt = true
            }
            .buttonStyle(.borderedProminent)
            .tint(VColors.primary)
        }
    }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

#Preview {
    DebtLedgerView()
}
