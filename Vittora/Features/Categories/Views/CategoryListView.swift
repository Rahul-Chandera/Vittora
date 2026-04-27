import SwiftUI

struct CategoryListView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: CategoryListViewModel?
    @State private var showAddCategory = false
    @State private var showingDeleteAlert = false
    @State private var categoryToDelete: UUID?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "Categories"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddCategory = true
                } label: {
                    Image(systemName: VIcons.Actions.add)
                }
            }
        }
        .sheet(isPresented: $showAddCategory) {
            if let vm = viewModel {
                NavigationStack {
                    CategoryFormView(onSave: {
                        Task { await vm.loadCategories() }
                    })
                }
            }
        }
        .alert(String(localized: "Delete Category"), isPresented: $showingDeleteAlert) {
            Button(String(localized: "Delete"), role: .destructive) {
                if let id = categoryToDelete, let vm = viewModel {
                    Task { await vm.deleteCategory(id: id) }
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "Are you sure you want to delete this category?"))
        }
        .task {
            await setupViewModel()
        }
    }

    @MainActor
    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let deps = dependencies
        guard let categoryRepo = deps.categoryRepository else { return }

        let vm = CategoryListViewModel(
            fetchUseCase: FetchCategoriesUseCase(repository: categoryRepo),
            deleteUseCase: DeleteCategoryUseCase(repository: categoryRepo),
            reorderUseCase: ReorderCategoriesUseCase(repository: categoryRepo)
        )
        viewModel = vm
        await vm.loadCategories()
    }

    @ViewBuilder
    private func content(vm: CategoryListViewModel) -> some View {
        if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.expenseCategories.isEmpty && vm.incomeCategories.isEmpty {
            emptyState
        } else {
            categoryList(vm: vm)
        }
    }

    private var emptyState: some View {
        VStack(spacing: VSpacing.md) {
            Image(systemName: "tag.fill")
                .font(.system(size: 48))
                .foregroundColor(VColors.textTertiary)
            Text(String(localized: "No Categories"))
                .font(VTypography.title3)
                .foregroundColor(VColors.textPrimary)
            Text(String(localized: "Add categories to organise your transactions."))
                .font(VTypography.body)
                .foregroundColor(VColors.textSecondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "Add Category")) { showAddCategory = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(VSpacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func categoryList(vm: CategoryListViewModel) -> some View {
        List {
            if !vm.filteredExpenseCategories.isEmpty {
                Section(String(localized: "Expense")) {
                    ForEach(vm.filteredExpenseCategories) { category in
                        NavigationLink(value: NavigationDestination.categoryDetail(id: category.id)) {
                            CategoryRowView(category: category)
                        }
                        .swipeActions(edge: .trailing) {
                            if !category.isDefault {
                                Button(role: .destructive) {
                                    categoryToDelete = category.id
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            NavigationLink(value: NavigationDestination.categoryDetail(id: category.id)) {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove { indices, newOffset in
                        Task {
                            var reordered = vm.filteredExpenseCategories
                            reordered.move(fromOffsets: indices, toOffset: newOffset)
                            await vm.reorder(type: .expense, orderedIDs: reordered.map(\.id))
                        }
                    }
                }
            }

            if !vm.filteredIncomeCategories.isEmpty {
                Section(String(localized: "Income")) {
                    ForEach(vm.filteredIncomeCategories) { category in
                        NavigationLink(value: NavigationDestination.categoryDetail(id: category.id)) {
                            CategoryRowView(category: category)
                        }
                        .swipeActions(edge: .trailing) {
                            if !category.isDefault {
                                Button(role: .destructive) {
                                    categoryToDelete = category.id
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .onMove { indices, newOffset in
                        Task {
                            var reordered = vm.filteredIncomeCategories
                            reordered.move(fromOffsets: indices, toOffset: newOffset)
                            await vm.reorder(type: .income, orderedIDs: reordered.map(\.id))
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
            get: { viewModel?.searchQuery ?? "" },
            set: { viewModel?.searchQuery = $0 }
        ))
        .refreshable { await vm.loadCategories() }
    }
}

#Preview {
    NavigationStack {
        CategoryListView()
    }
}
