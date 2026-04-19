import SwiftUI

struct PayeeDetailView: View {
    let payeeID: UUID
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: PayeeDetailViewModel?
    @State private var showEditSheet = false

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel?.payee?.name ?? "Payee")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditSheet = true }
                    .disabled(viewModel?.payee == nil)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let payee = viewModel?.payee {
                NavigationStack {
                    PayeeFormView(editingPayee: payee) {
                        Task { await viewModel?.loadPayee(id: payeeID) }
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
        guard let payeeRepo = deps.payeeRepository,
              let transactionRepo = deps.transactionRepository else { return }

        let vm = PayeeDetailViewModel(
            payeeRepository: payeeRepo,
            analyticsUseCase: PayeeAnalyticsUseCase(transactionRepository: transactionRepo),
            transactionRepository: transactionRepo
        )
        viewModel = vm
        await vm.loadPayee(id: payeeID)
    }

    @ViewBuilder
    private func content(vm: PayeeDetailViewModel) -> some View {
        if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let payee = vm.payee {
            payeeDetail(payee: payee, vm: vm)
        } else {
            Text("Payee not found")
                .foregroundColor(VColors.textSecondary)
        }
    }

    @ViewBuilder
    private func payeeDetail(payee: PayeeEntity, vm: PayeeDetailViewModel) -> some View {
        List {
            // Header
            Section {
                HStack(spacing: VSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(payee.type == .business ? VColors.primary.opacity(0.15) : VColors.income.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: payee.type == .business ? "building.2.fill" : "person.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(payee.type == .business ? VColors.primary : VColors.income)
                    }
                    VStack(alignment: .leading, spacing: VSpacing.xxs) {
                        Text(payee.name)
                            .font(VTypography.title3)
                            .foregroundColor(VColors.textPrimary)
                        Text(payee.type == .business ? "Business" : "Person")
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.textSecondary)
                    }
                }
                .padding(.vertical, VSpacing.xs)
            }

            // Analytics
            if let analytics = vm.analytics {
                Section {
                    PayeeAnalyticsCard(analytics: analytics)
                        .listRowInsets(EdgeInsets(top: VSpacing.xs, leading: VSpacing.screenPadding, bottom: VSpacing.xs, trailing: VSpacing.screenPadding))
                        .listRowBackground(Color.clear)
                }
            }

            // Contact Info
            Section("Contact") {
                LabeledContent("Name", value: payee.name)
                if let phone = payee.phone {
                    LabeledContent("Phone", value: phone)
                }
                if let email = payee.email {
                    LabeledContent("Email", value: email)
                }
                if let notes = payee.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: VSpacing.xxs) {
                        Text("Notes")
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.textSecondary)
                        Text(notes)
                            .font(VTypography.body)
                            .foregroundColor(VColors.textPrimary)
                    }
                    .padding(.vertical, VSpacing.xxs)
                }
            }

            // Recent Transactions
            if !vm.recentTransactions.isEmpty {
                Section("Recent Transactions") {
                    ForEach(vm.recentTransactions) { tx in
                        NavigationLink(value: NavigationDestination.transactionDetail(id: tx.id)) {
                            HStack(spacing: VSpacing.sm) {
                                VStack(alignment: .leading, spacing: VSpacing.xxs) {
                                    Text(tx.note ?? "Transaction")
                                        .font(VTypography.body)
                                        .foregroundColor(VColors.textPrimary)
                                        .adaptiveLineLimit(1)
                                    Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(VTypography.caption1)
                                        .foregroundColor(VColors.textSecondary)
                                }
                                Spacer()
                                Text(tx.amount.formatted(.currency(code: "USD")))
                                    .font(VTypography.bodyBold)
                                    .foregroundColor(tx.type == .income ? VColors.income : VColors.expense)
                            }
                            .padding(.vertical, VSpacing.xxs)
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
        .refreshable { await vm.loadPayee(id: payeeID) }
    }
}

#Preview {
    NavigationStack {
        PayeeDetailView(payeeID: UUID())
    }
}
