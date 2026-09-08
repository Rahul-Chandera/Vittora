import SwiftUI
import VittoraCore

struct CategorizationRulesView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: CategorizationRulesViewModel?
    @State private var showAddRule = false
    @State private var ruleToEdit: CategorizationRuleRowModel?
    /// A rule the user wrote by hand; deleting it silently was the last of the
    /// unguarded deletes.
    @State private var ruleToDelete: CategorizationRuleRowModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "Categorization Rules"))
        .confirmationDialog(
            String(localized: "Delete this rule?"),
            isPresented: Binding(
                get: { ruleToDelete != nil },
                set: { if !$0 { ruleToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                guard let rule = ruleToDelete, let viewModel else { return }
                ruleToDelete = nil
                Task { await viewModel.deleteRule(id: rule.id) }
            }
            Button(String(localized: "Cancel"), role: .cancel) { ruleToDelete = nil }
        } message: {
            Text(String(localized: "Transactions will stop being categorised by this rule. Ones it has already categorised keep their category. This cannot be undone."))
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    ruleToEdit = nil
                    showAddRule = true
                } label: {
                    Image(systemName: VIcons.Actions.add)
                }
                .accessibilityLabel(String(localized: "Add rule"))
            }
        }
        .sheet(isPresented: $showAddRule) {
            if let vm = viewModel {
                NavigationStack {
                    CategorizationRuleFormView(
                        categories: vm.categories,
                        existingRule: ruleToEdit.map {
                            CategorizationRule(
                                id: $0.id,
                                keyword: $0.keyword,
                                categoryID: $0.categoryID,
                                isEnabled: $0.isEnabled
                            )
                        },
                        onSave: {
                            Task { await vm.load() }
                        }
                    )
                }
            }
        }
        .errorAlert(message: errorBinding)
        .task {
            await setupViewModel()
        }
    }

    @ViewBuilder
    private func content(vm: CategorizationRulesViewModel) -> some View {
        if vm.isLoading && vm.rules.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.rules.isEmpty {
            emptyState
        } else {
            List {
                Section {
                    ForEach(vm.rules) { rule in
                        ruleRow(rule, vm: vm)
                    }
                } footer: {
                    Text(
                        String(
                            localized: "Rules match keywords in payee names, notes, and receipt merchant text. Longer keywords take priority."
                        )
                    )
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .refreshable { await vm.load() }
        }
    }

    private func ruleRow(_ rule: CategorizationRuleRowModel, vm: CategorizationRulesViewModel) -> some View {
        HStack(spacing: VSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.keyword)
                    .font(VTypography.bodyBold)
                    .foregroundStyle(VColors.textPrimary)
                HStack(spacing: VSpacing.xs) {
                    Image(systemName: rule.categoryIcon)
                        .foregroundStyle(Color(hex: rule.categoryColorHex) ?? VColors.primaryOnSurface)
                    Text(rule.categoryName)
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { newValue in
                    Task { await vm.toggleRule(id: rule.id, isEnabled: newValue) }
                }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            ruleToEdit = rule
            showAddRule = true
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                ruleToDelete = rule
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: VSpacing.md) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(VColors.textTertiary)
            Text(String(localized: "No Rules Yet"))
                .font(VTypography.title3)
                .foregroundStyle(VColors.textPrimary)
            Text(
                String(
                    localized: "Add keyword rules to automatically suggest categories for matching payees and notes."
                )
            )
            .font(VTypography.body)
            .foregroundStyle(VColors.textSecondary)
            .multilineTextAlignment(.center)
            Button(String(localized: "Add Rule")) { showAddRule = true }
                .buttonStyle(.borderedProminent)
                .tint(VColors.primary)
        }
        .padding(VSpacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = dependencies.makeCategorizationRulesViewModel()
        viewModel = vm
        await vm.load()
    }

    private var errorBinding: Binding<String?> {
        Binding(
            get: { viewModel?.error },
            set: { viewModel?.error = $0 }
        )
    }
}

struct CategorizationRuleFormView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CategorizationRuleFormViewModel?

    let categories: [CategoryEntity]
    let existingRule: CategorizationRule?
    let onSave: () -> Void

    var body: some View {
        Group {
            if let vm = viewModel {
                Form {
                    Section {
                        TextField(String(localized: "Keyword"), text: Bindable(vm).keyword)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                    } header: {
                        VFormSectionHeader(String(localized: "Keyword"))
                    } footer: {
                        Text(String(localized: "Matches when this word appears in a payee name, note, or receipt merchant text."))
                    }

                    Section {
                        Picker(String(localized: "Category"), selection: Bindable(vm).selectedCategoryID) {
                            Text(String(localized: "Select category")).tag(UUID?.none)
                            ForEach(categories.filter { $0.type == .expense }) { category in
                                HStack {
                                    Image(systemName: category.icon)
                                        .foregroundStyle(Color(hex: category.colorHex) ?? .blue)
                                    Text(category.displayName)
                                }
                                .tag(UUID?(category.id))
                            }
                        }
                    } header: {
                        VFormSectionHeader(String(localized: "Category"))
                    }

                    Section {
                        Toggle(String(localized: "Enabled"), isOn: Bindable(vm).isEnabled)
                    }
                }
                .navigationTitle(
                    existingRule == nil
                        ? String(localized: "New Rule")
                        : String(localized: "Edit Rule")
                )
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cancel")) { dismiss() }
                        .vDialogCancelButton()
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Save")) {
                            Task {
                                if await vm.save() {
                                    onSave()
                                    dismiss()
                                }
                            }
                        }
                        .disabled(!vm.canSave || vm.isSaving)
                        .vDialogConfirmButton()
                    }
                }
                .errorAlert(message: formErrorBinding)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = CategorizationRuleFormViewModel(
                    manageRulesUseCase: ManageCategorizationRulesUseCase(
                        ruleStore: dependencies.categorizationRuleStore,
                        categoryRepository: dependencies.categoryRepository
                    ),
                    existingRule: existingRule
                )
            }
        }
    }

    private var formErrorBinding: Binding<String?> {
        Binding(
            get: { viewModel?.error },
            set: { viewModel?.error = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        CategorizationRulesView()
    }
}
