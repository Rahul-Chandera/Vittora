import SwiftUI
import VittoraCore

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
            // Fill first, then paint — a ZStack sizes to its child, so the page
            // colour would only cover the empty/error state's own height.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VColors.groupedBackground)
            .navigationTitle(String(localized: "Debt Ledger"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddDebt = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "Add debt entry"))
                    .accessibilityHint(String(localized: "Opens the debt entry form"))
                    .accessibilityIdentifier("debt-add-button")
                }
            }
            .navigationDestination(item: $selectedPayeeID) { payeeID in
                DebtDetailView(payeeID: payeeID)
            }
        }
        .task {
            if vm == nil {
                vm = dependencies.makeDebtLedgerViewModel()
                await vm?.load()
            }
        }
        .task(id: appState.refreshVersion(for: .debt)) {
            guard vm != nil, appState.refreshVersion(for: .debt) > 0 else { return }
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
        // Clearance for the floating tab bar. safeAreaPadding, not
        // safeAreaInset: this screen is a stack of cards, and an opaque inset
        // paints OVER the last one, slicing it mid-glyph — which the audit's
        // contrast sampler reads as failing text at AccessibilityXL.
        // Padding reserves the same space without drawing.
        //
        // Dashboard and the report screens keep their inset: they are the ones
        // where removing it lets content render in the gutter below the tab
        // bar, which the audit reports as text with no accessible element.
        .safeAreaPadding(.bottom, 72)
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
                    .contextMenu {
                        Button {
                            selectedPayeeID = entry.payee.id
                        } label: {
                            Label(String(localized: "View Ledger"), systemImage: "doc.text")
                        }
                    }

                    if entry.id != entries.last?.id {
                        Divider().padding(.leading, VSpacing.lg)
                    }
                }
            }
            .background(VColors.secondaryGroupedBackground)
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
