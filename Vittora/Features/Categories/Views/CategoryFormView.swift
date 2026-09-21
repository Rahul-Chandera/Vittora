import SwiftUI
import VittoraCore

struct CategoryFormView: View {
    var editingCategory: CategoryEntity? = nil
    /// Show a Cancel button. Only pass `true` when presenting modally; a pushed
    /// form already has a back button, so Cancel would be a duplicate.
    var showsCancelButton: Bool = false
    var onSave: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CategoryFormViewModel?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showIconPicker = false
    @State private var showColorPicker = false
    @State private var allCategories: [CategoryEntity] = []

    var body: some View {
        Group {
            if let vm = viewModel {
                formContent(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(editingCategory == nil ? String(localized: "New Category") : String(localized: "Edit Category"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if showsCancelButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                    .vDialogCancelButton()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save")) {
                    Task { await save() }
                }
                .disabled(viewModel?.canSave != true || isSaving)
                .vDialogConfirmButton()
            }
        }
        .task {
            setupViewModel()
            await loadCategories()
        }
        .onChange(of: saveError) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
            }
        }
    }

    /// The parent picker needs the whole list to apply the hierarchy rules — which
    /// candidates are roots, which already have children — so it cannot be derived from the
    /// category being edited alone.
    private func loadCategories() async {
        allCategories = (try? await dependencies.categoryRepository.fetchAll()) ?? []
    }

    private var eligibleParents: [CategoryEntity] {
        CategoryHierarchy.eligibleParents(
            for: editingCategory,
            in: allCategories,
            type: viewModel?.selectedType ?? .expense
        )
    }

    private var blockedByOwnChildren: Bool {
        guard let editingCategory else { return false }
        return CategoryHierarchy.hasChildren(editingCategory, in: allCategories)
    }

    /// One level of nesting only, so the rules in `CategoryHierarchy` decide what may
    /// appear here rather than the picker offering everything and failing on save.
    @ViewBuilder
    private func parentPicker(vm: CategoryFormViewModel) -> some View {
        if blockedByOwnChildren {
            // Explaining beats hiding: a parent with children simply cannot become a child,
            // and a picker that silently vanished would read as a bug.
            Text(String(localized: "This category has sub-categories, so it cannot be moved under another one."))
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("category-parent-blocked-note")
        } else if eligibleParents.isEmpty {
            EmptyView()
        } else {
            Picker(String(localized: "Parent Category"), selection: Bindable(vm).selectedParentID) {
                Text(String(localized: "None")).tag(UUID?.none)
                ForEach(eligibleParents) { parent in
                    Text(parent.displayName).tag(UUID?.some(parent.id))
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("category-parent-picker")
            // Switching Expense to Income strands a parent of the old type: it is no
            // longer in the list, so the Picker renders blank while still holding the id,
            // and saving would write a cross-type parent.
            .onChange(of: vm.selectedType) { _, _ in
                if let parentID = vm.selectedParentID,
                   !eligibleParents.contains(where: { $0.id == parentID }) {
                    vm.selectedParentID = nil
                }
            }

            Text(String(localized: "Sub-categories group under their parent in lists and reports. Nesting is one level deep."))
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func setupViewModel() {
        guard viewModel == nil else { return }

        let vm = CategoryFormViewModel(
            createUseCase: CreateCategoryUseCase(repository: dependencies.categoryRepository),
            updateUseCase: UpdateCategoryUseCase(repository: dependencies.categoryRepository)
        )
        if let category = editingCategory {
            vm.loadCategory(category)
        }
        viewModel = vm
    }

    @ViewBuilder
    private func formContent(vm: CategoryFormViewModel) -> some View {
        Form {
            // Preview
            Section {
                HStack(spacing: VSpacing.md) {
                    let tint = Color(hex: vm.selectedColorHex) ?? .blue
                    ZStack {
                        Circle()
                            .fill(tint)
                            .opacity(0.15)
                            .frame(width: 56, height: 56)
                        Image(systemName: vm.selectedIcon)
                            .font(.title2.weight(.semibold))
                            .foregroundColor(VColors.textPrimary)
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: VSpacing.xxs) {
                        Text(vm.name.isEmpty ? String(localized: "Category Name") : vm.name)
                            .font(VTypography.bodyBold)
                            .foregroundColor(VColors.textPrimary)
                        Text(vm.selectedType == .expense ? String(localized: "Expense") : String(localized: "Income"))
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.textPrimary)
                    }
                }
                .padding(.vertical, VSpacing.xs)
            } header: {
                VFormSectionHeader(String(localized: "Preview"))
            }
            .headerProminence(.increased)

            Section {
                TextField(String(localized: "Category Name"), text: Bindable(vm).name, axis: .vertical)
                    .lineLimit(1...2)

                Picker(String(localized: "Type"), selection: Bindable(vm).selectedType) {
                    Text(String(localized: "Expense")).tag(CategoryType.expense)
                    Text(String(localized: "Income")).tag(CategoryType.income)
                }
                .pickerStyle(.menu)

                if vm.selectedType == .expense {
                    Picker(
                        String(localized: "50/30/20 Bucket"),
                        selection: Bindable(vm).selectedSpendingBucket
                    ) {
                        ForEach(SpendingBucket.allCases, id: \.self) { bucket in
                            Text(bucket.displayName).tag(bucket)
                        }
                    }
                    Text(
                        String(
                            localized: "Choose how this category appears in the 50/30/20 report."
                        )
                    )
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                }
                parentPicker(vm: vm)
            } header: {
                VFormSectionHeader(String(localized: "Details"))
            }
            .headerProminence(.increased)

            Section {
                let selectedColor = Color(hex: vm.selectedColorHex) ?? .blue
                NavigationLink(destination: CategoryIconPicker(
                    selectedIcon: Bindable(vm).selectedIcon,
                    selectedColor: selectedColor
                )) {
                    HStack {
                        Text(String(localized: "Icon"))
                        Spacer()
                        Image(systemName: vm.selectedIcon)
                            .foregroundColor(VColors.textPrimary)
                            .accessibilityHidden(true)
                    }
                }

                NavigationLink(destination: CategoryColorPicker(selectedColorHex: Bindable(vm).selectedColorHex)) {
                    HStack {
                        Text(String(localized: "Color"))
                        Spacer()
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Circle().stroke(VColors.textPrimary, lineWidth: 2)
                            }
                            .accessibilityLabel(String(localized: "Selected category color"))
                    }
                }
            } header: {
                VFormSectionHeader(String(localized: "Appearance"))
            }
            .headerProminence(.increased)

            if let error = saveError {
                Section {
                    VInlineErrorText(error)
                }
            }
        }
        .tint(VColors.textCursor)
    }

    private func save() async {
        guard let vm = viewModel else { return }
        isSaving = true
        saveError = nil
        do {
            try await vm.save()
            appState.notifyChanged(.categories)
            onSave?()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

#Preview {
    NavigationStack {
        CategoryFormView()
    }
}
