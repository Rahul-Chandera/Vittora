import SwiftUI

@Observable
@MainActor
final class DataManagementViewModel {
    var stats: DatabaseStats?
    var isLoading = false
    var isClearing = false
    var error: String?
    var clearScope: ClearDataScope = .transactions
    var showClearConfirm = false
    var showFactoryResetConfirm = false

    private let service: DataManagementService

    init(service: DataManagementService) {
        self.service = service
    }

    func loadStats() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            stats = try await service.fetchStats()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearData() async {
        isClearing = true
        error = nil
        defer { isClearing = false }
        do {
            try await service.clearData(scope: clearScope)
            await loadStats()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func factoryReset() async {
        isClearing = true
        error = nil
        defer { isClearing = false }
        do {
            try await service.factoryReset()
            await loadStats()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct DataManagementView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: DataManagementViewModel?

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "Manage Data"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if vm == nil { setupVM() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ vm: DataManagementViewModel) -> some View {
        Form {
            // Database stats
            Section(String(localized: "Database")) {
                if vm.isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let stats = vm.stats {
                    statRow(String(localized: "Transactions"), count: stats.transactionCount, icon: "list.bullet.rectangle.fill")
                    statRow(String(localized: "Accounts"), count: stats.accountCount, icon: "building.columns.fill")
                    statRow(String(localized: "Categories"), count: stats.categoryCount, icon: "tag.fill")
                    statRow(String(localized: "Budgets"), count: stats.budgetCount, icon: "target")
                    statRow(String(localized: "Debts"), count: stats.debtCount, icon: "hand.point.up.left.fill")
                    statRow(String(localized: "Savings Goals"), count: stats.savingsGoalCount, icon: "star.circle.fill")
                    statRow(String(localized: "Split Groups"), count: stats.splitGroupCount, icon: "person.3.fill")
                    statRow(String(localized: "Documents"), count: stats.documentCount, icon: "doc.fill")
                    HStack {
                        Text(String(localized: "Total records"))
                            .font(VTypography.bodyBold)
                        Spacer()
                        Text("\(stats.totalRecords)")
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.primary)
                    }
                } else {
                    Button(String(localized: "Load Statistics")) {
                        Task { await vm.loadStats() }
                    }
                }
            }

            // Export
            Section(String(localized: "Export")) {
                NavigationLink {
                    ExportView()
                } label: {
                    Label(String(localized: "Export as CSV"), systemImage: "square.and.arrow.up")
                }
            }

            // Clear data
            Section {
                Picker(String(localized: "Clear"), selection: Bindable(vm).clearScope) {
                    ForEach(ClearDataScope.allCases.filter { $0 != .all }, id: \.self) { scope in
                        Text(scope.displayName).tag(scope)
                    }
                }

                Button(role: .destructive) {
                    vm.showClearConfirm = true
                } label: {
                    if vm.isClearing {
                        HStack { ProgressView(); Text(String(localized: "Clearing…")) }
                    } else {
                        Label(String(localized: "Clear \(vm.clearScope.displayName)"), systemImage: "trash")
                    }
                }
                .disabled(vm.isClearing)
            } header: {
                Text(String(localized: "Clear Data"))
            } footer: {
                Text(String(localized: "Permanently deletes the selected data. This cannot be undone."))
                    .foregroundStyle(VColors.textSecondary)
            }

            // Factory reset
            Section {
                Button(role: .destructive) {
                    vm.showFactoryResetConfirm = true
                } label: {
                    Label(String(localized: "Factory Reset"), systemImage: "arrow.counterclockwise")
                }
                .disabled(vm.isClearing)
            } footer: {
                Text(String(localized: "Deletes ALL data including accounts and categories, and resets onboarding."))
                    .foregroundStyle(VColors.textSecondary)
            }

            if let error = vm.error {
                Section {
                    HStack(spacing: VSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(VColors.expense)
                        Text(error)
                            .font(VTypography.caption1)
                    }
                }
            }
        }
        .refreshable { await vm.loadStats() }
        .confirmationDialog(
            String(localized: "Clear \(vm.clearScope.displayName)?"),
            isPresented: Bindable(vm).showClearConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete \(vm.clearScope.displayName)"), role: .destructive) {
                Task { await vm.clearData() }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This will permanently delete all \(vm.clearScope.displayName.lowercased()). This cannot be undone."))
        }
        .confirmationDialog(
            String(localized: "Factory Reset?"),
            isPresented: Bindable(vm).showFactoryResetConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Reset Everything"), role: .destructive) {
                Task { await vm.factoryReset() }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This will permanently erase ALL your data and reset the app to its initial state. This cannot be undone."))
        }
    }

    // MARK: - Helpers

    private func statRow(_ label: String, count: Int, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(VColors.textPrimary)
            Spacer()
            Text("\(count)")
                .foregroundStyle(VColors.textSecondary)
                .font(VTypography.body)
        }
    }

    private func setupVM() {
        guard let txRepo = dependencies.transactionRepository,
              let accRepo = dependencies.accountRepository,
              let catRepo = dependencies.categoryRepository,
              let budRepo = dependencies.budgetRepository,
              let debtRepo = dependencies.debtRepository,
              let goalRepo = dependencies.savingsGoalRepository,
              let splitRepo = dependencies.splitGroupRepository,
              let docRepo = dependencies.documentRepository else { return }

        let service = DataManagementService(
            transactionRepository: txRepo,
            accountRepository: accRepo,
            categoryRepository: catRepo,
            budgetRepository: budRepo,
            debtRepository: debtRepo,
            savingsGoalRepository: goalRepo,
            splitGroupRepository: splitRepo,
            documentRepository: docRepo,
            keychainService: dependencies.keychainService ?? KeychainService()
        )
        vm = DataManagementViewModel(service: service)
        Task { await vm?.loadStats() }
    }
}
