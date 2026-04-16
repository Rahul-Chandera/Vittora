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
            if let vm = viewModel {
                ToolbarItem(placement: .automatic) {
                    importContactsButton(vm: vm)
                }
            }

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
        .alert(
            String(localized: "Contacts Imported"),
            isPresented: Binding(
                get: { viewModel?.importSummary != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel?.clearImportSummary()
                    }
                }
            )
        ) {
            Button(String(localized: "OK")) {
                viewModel?.clearImportSummary()
            }
        } message: {
            Text(viewModel?.importSummaryMessage ?? "")
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
            ),
            importContactsUseCase: deps.contactsImportService.map {
                ImportContactsUseCase(
                    repository: payeeRepo,
                    contactsService: $0
                )
            }
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
            emptyState(vm: vm)
        } else {
            payeeList(vm: vm)
        }
    }

    private func emptyState(vm: PayeeListViewModel) -> some View {
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
            Button {
                Task { await vm.importContacts() }
            } label: {
                if vm.isImportingContacts {
                    ProgressView()
                } else {
                    Text(String(localized: "Import from Contacts"))
                }
            }
            .buttonStyle(.bordered)
            .disabled(vm.isImportingContacts)
        }
        .padding(VSpacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func payeeList(vm: PayeeListViewModel) -> some View {
        List {
            if !vm.frequentSectionPayees.isEmpty {
                Section(String(localized: "Frequent")) {
                    payeeRows(for: vm.frequentSectionPayees)
                }
            }

            ForEach(vm.sectionedPayees, id: \.letter) { section in
                Section(section.letter) {
                    payeeRows(for: section.payees)
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

    @ViewBuilder
    private func payeeRows(for payees: [PayeeEntity]) -> some View {
        ForEach(payees) { payee in
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

    @ViewBuilder
    private func importContactsButton(vm: PayeeListViewModel) -> some View {
        Button {
            Task { await vm.importContacts() }
        } label: {
            #if os(macOS)
            if vm.isImportingContacts {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label(String(localized: "Import"), systemImage: "person.crop.circle.badge.plus")
            }
            #else
            if vm.isImportingContacts {
                ProgressView()
            } else {
                Image(systemName: "person.crop.circle.badge.plus")
            }
            #endif
        }
        .disabled(vm.isImportingContacts)
        .help(String(localized: "Import from Contacts"))
    }
}

#Preview {
    NavigationStack {
        PayeeListView()
    }
}
