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
                        .font(.body)
                        .foregroundStyle(VColors.textPrimary)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save")) {
                    Task { await save() }
                }
                .disabled(viewModel?.canSave != true || isSaving)
                .font(.body)
                .foregroundStyle(VColors.textPrimary)
            }
        }
        .task {
            setupViewModel()
        }
        .onChange(of: saveError) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
            }
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
        .tint(VColors.textPrimary)
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
