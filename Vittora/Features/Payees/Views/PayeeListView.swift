import SwiftUI

struct PayeeListView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: PayeeListViewModel?
    @State private var showAddPayee = false
    @State private var showingDeleteAlert = false
    @State private var payeeToDelete: UUID?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Payees")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddPayee = true
                } label: {
                    Image(systemName: VIcons.Actions.add)
                }
            }
        }
        .sheet(isPresented: $showAddPayee) {
            if let vm = viewModel {
                NavigationStack {
                    PayeeFormView(onSave: {
                        Task { await vm.loadPayees() }
                    })
                }
            }
        }
        .alert("Delete Payee", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let id = payeeToDelete, let vm = viewModel {
                    Task { await vm.deletePayee(id: id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this payee?")
        }
        .task {
            await setupViewModel()
        }
    }

    @MainActor
    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let deps = dependencies
        guard let payeeRepo = deps.payeeRepository,
              let transactionRepo = deps.transactionRepository else { return }

        let vm = PayeeListViewModel(
            fetchUseCase: FetchPayeesUseCase(repository: payeeRepo),
            deleteUseCase: DeletePayeeUseCase(
                repository: payeeRepo,
                transactionRepository: transactionRepo
            )
        )
        viewModel = vm
        await vm.loadPayees()
    }

    @ViewBuilder
    private func content(vm: PayeeListViewModel) -> some View {
        if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.payees.isEmpty {
            emptyState
        } else {
            payeeList(vm: vm)
        }
    }

    private var emptyState: some View {
        VStack(spacing: VSpacing.md) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundColor(VColors.textTertiary)
            Text("No Payees")
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)
            Text("Add payees to track who you pay or receive money from.")
                .font(VTypography.body)
                .foregroundColor(VColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Add Payee") { showAddPayee = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(VSpacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func payeeList(vm: PayeeListViewModel) -> some View {
        List {
            ForEach(vm.sectionedPayees, id: \.letter) { section in
                Section(section.letter) {
                    ForEach(section.payees) { payee in
                        NavigationLink(value: NavigationDestination.payeeDetail(id: payee.id)) {
                            PayeeRowView(payee: payee)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                payeeToDelete = payee.id
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
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
        .searchable(text: Binding(
            get: { vm.searchQuery },
            set: { vm.searchQuery = $0 }
        ), prompt: "Search payees")
        .refreshable { await vm.loadPayees() }
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
}

#Preview {
    NavigationStack {
        PayeeListView()
    }
}
