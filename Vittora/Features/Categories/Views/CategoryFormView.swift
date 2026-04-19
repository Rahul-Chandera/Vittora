import SwiftUI

struct CategoryFormView: View {
    var editingCategory: CategoryEntity? = nil
    var onSave: (() -> Void)? = nil

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
        .navigationTitle(editingCategory == nil ? "New Category" : "Edit Category")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(viewModel?.canSave != true || isSaving)
            }
        }
        .task {
            setupViewModel()
        }
        .onChange(of: saveError) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(Text(msg)).post()
            }
        }
    }

    private func setupViewModel() {
        guard viewModel == nil else { return }
        let deps = dependencies
        guard let categoryRepo = deps.categoryRepository else { return }

        let vm = CategoryFormViewModel(
            createUseCase: CreateCategoryUseCase(repository: categoryRepo),
            updateUseCase: UpdateCategoryUseCase(repository: categoryRepo)
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
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(tint)
                    }
                    VStack(alignment: .leading, spacing: VSpacing.xxs) {
                        Text(vm.name.isEmpty ? "Category Name" : vm.name)
                            .font(VTypography.bodyBold)
                            .foregroundColor(vm.name.isEmpty ? VColors.textTertiary : VColors.textPrimary)
                        Text(vm.selectedType == .expense ? "Expense" : "Income")
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.textSecondary)
                    }
                }
                .padding(.vertical, VSpacing.xs)
            } header: {
                Text("Preview")
            }

            Section("Details") {
                TextField("Category Name", text: Bindable(vm).name)

                Picker("Type", selection: Bindable(vm).selectedType) {
                    Text("Expense").tag(CategoryType.expense)
                    Text("Income").tag(CategoryType.income)
                }
                .pickerStyle(.segmented)
            }

            Section("Appearance") {
                let selectedColor = Color(hex: vm.selectedColorHex) ?? .blue
                NavigationLink(destination: CategoryIconPicker(
                    selectedIcon: Bindable(vm).selectedIcon,
                    selectedColor: selectedColor
                )) {
                    HStack {
                        Text("Icon")
                        Spacer()
                        Image(systemName: vm.selectedIcon)
                            .foregroundColor(selectedColor)
                    }
                }

                NavigationLink(destination: CategoryColorPicker(selectedColorHex: Bindable(vm).selectedColorHex)) {
                    HStack {
                        Text("Color")
                        Spacer()
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 24, height: 24)
                    }
                }
            }

            if let error = saveError {
                Section {
                    Text(error)
                        .foregroundColor(VColors.expense)
                        .font(VTypography.caption1)
                }
            }
        }
    }

    private func save() async {
        guard let vm = viewModel else { return }
        isSaving = true
        saveError = nil
        do {
            try await vm.save()
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
