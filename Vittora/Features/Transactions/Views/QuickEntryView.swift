import SwiftUI
import VittoraCore

struct QuickEntryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: TransactionFormViewModel?
    @State private var categories: [CategoryEntity] = []
    @State private var accounts: [AccountEntity] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            if let vm = vm {
                ZStack {
                    VStack(spacing: VSpacing.lg) {
                        // Large amount input
                        AmountInputView(
                            amountString: Bindable(vm).amountString,
                            currencyCode: currencyCode,
                            type: .expense,
                            // Quick entry exists to type an amount fast, so the
                            // keyboard should already be up.
                            autoFocus: true
                        )
                        .padding(VSpacing.lg)

                        // Account picker
                        Picker(String(localized: "Account"), selection: Bindable(vm).selectedAccountID) {
                            Text(String(localized: "Select account")).tag(UUID?.none)
                            ForEach(accounts) { account in
                                Text(account.name).tag(UUID?(account.id))
                            }
                        }
                        .padding(.horizontal, VSpacing.lg)

                        // Quick category grid
                        VStack(alignment: .leading, spacing: VSpacing.sm) {
                            Text(String(localized: "Category"))
                                .font(VTypography.caption2)
                                .foregroundColor(VColors.textSecondary)
                                .padding(.horizontal, VSpacing.lg)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: VSpacing.md) {
                                    ForEach(categories.prefix(8)) { category in
                                        Button {
                                            vm.selectedCategoryID = category.id
                                        } label: {
                                            VStack(spacing: VSpacing.xs) {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color(hex: category.colorHex) ?? .blue)
                                                        .frame(width: 44, height: 44)

                                                    Image(systemName: category.icon)
                                                        .font(.title3)
                                                        .foregroundColor(.white)
                                                }

                                                Text(category.displayName)
                                                    .font(VTypography.caption2)
                                                    .foregroundColor(VColors.textPrimary)
                                                    .adaptiveLineLimit(1)
                                            }
                                            .frame(width: 60)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .opacity(vm.selectedCategoryID == category.id ? 1.0 : 0.6)
                                        .accessibilityAddTraits(
                                            vm.selectedCategoryID == category.id ? .isSelected : []
                                        )
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, VSpacing.lg)
                            }
                        }

                        Spacer()

                        // Save button
                        Button {
                            Task {
                                do {
                                    try await vm.save()
                                    await dependencies.conversionEventRecorder.afterTransactionCreated()
                                    await dependencies.refreshBudgetThresholdAlerts()
                                    appState.notifyChanged([.transactions, .accounts, .budgets])
                                    #if os(iOS)
                                    let feedback = UIImpactFeedbackGenerator(style: .light)
                                    feedback.impactOccurred()
                                    #endif
                                    dismiss()
                                } catch {
                                    vm.error = error.userFacingMessage(
                                        fallback: String(localized: "We couldn't save this transaction.")
                                    )
                                }
                            }
                        } label: {
                            Text(String(localized: "Save Transaction"))
                                .font(VTypography.body)
                                .foregroundStyle(VColors.onPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(VSpacing.md)
                                .background(VColors.primary)
                                .cornerRadius(VSpacing.cornerRadiusSM)
                        }
                        // .plain: the label supplies its own appearance. Without it macOS
                        // draws the standard AppKit button chrome behind it — a second,
                        // lighter fill around the custom one (see QuickEntryButton).
                        .buttonStyle(.plain)
                        .disabled(!vm.canSave)
                        .keyboardShortcut(.defaultAction)
                        .padding(VSpacing.lg)
                    }
                    .padding(.top, VSpacing.lg)

                    if isLoading {
                        ProgressView()
                            .tint(VColors.primary)
                    }

                    if vm.isLoading {
                        ProgressView()
                            .tint(VColors.primary)
                    }
                }
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cancel")) {
                            dismiss()
                        }
                        .keyboardShortcut(.cancelAction)
                    }
                }
            }
        }
        .errorAlert(message: quickEntryErrorBinding)
        .task {
            if vm == nil {
                vm = createViewModel()
                await loadCategories()
            }
        }
    }

    private func loadCategories() async {
        isLoading = true
        defer { isLoading = false }

        let fetchCategoriesUseCase = FetchCategoriesUseCase(repository: dependencies.categoryRepository)
        let fetchAccountsUseCase = FetchAccountsUseCase(accountRepository: dependencies.accountRepository)
        var didFailToLoadOptions = false

        do {
            let groupedCategories = try await fetchCategoriesUseCase.executeGrouped()
            categories = groupedCategories.expense
        } catch {
            categories = []
            didFailToLoadOptions = true
        }

        do {
            accounts = try await fetchAccountsUseCase.execute()
        } catch {
            accounts = []
            didFailToLoadOptions = true
        }

        if didFailToLoadOptions {
            vm?.error = String(
                localized: "Some quick entry options couldn't be loaded. Please try again."
            )
        }

        if !accounts.isEmpty {
            vm?.selectedAccountID = accounts.first?.id
        }
    }

    private func createViewModel() -> TransactionFormViewModel {
        dependencies.makeQuickEntryViewModel(currencyCode: currencyCode)
    }

    private var quickEntryErrorBinding: Binding<String?> {
        Binding(
            get: { vm?.error },
            set: { newValue in
                vm?.error = newValue
            }
        )
    }
}

#Preview {
    QuickEntryView()
}
