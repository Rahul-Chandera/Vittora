import SwiftUI
import VittoraCore

struct CategoryListView: View {
    @Environment(AppState.self) private var appState
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
            ToolbarItem(placement: .automatic) {
                NavigationLink {
                    CategorizationRulesView()
                } label: {
                    Image(systemName: "text.magnifyingglass")
                }
                .accessibilityLabel(String(localized: "Categorization rules"))
            }
        }
        .sheet(isPresented: $showAddCategory) {
            if let vm = viewModel {
                NavigationStack {
                    CategoryFormView(showsCancelButton: true, onSave: {
                        Task { await vm.loadCategories() }
                    })
                }
            }
        }
        .alert(String(localized: "Delete Category"), isPresented: $showingDeleteAlert) {
            Button(String(localized: "Delete"), role: .destructive) {
                if let id = categoryToDelete, let vm = viewModel {
                    Task {
                        await vm.deleteCategory(id: id)
                        appState.notifyChanged(.categories)
                    }
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "Are you sure you want to delete this category?"))
        }
        .task {
            await setupViewModel()
        }
        .task(id: appState.refreshVersion(for: .categories)) {
            guard viewModel != nil, appState.refreshVersion(for: .categories) > 0 else { return }
            await viewModel?.loadCategories()
        }
    }

    @MainActor
    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = dependencies.makeCategoryListViewModel()
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
                        NavigationLink {
                            CategoryDetailView(categoryID: category.id)
                        } label: {
                            CategoryRowView(category: category)
                        }
                        .accessibilityIdentifier("category-row-\(category.name.lowercased())")
                        .contextMenu {
                            NavigationLink {
                                CategoryDetailView(categoryID: category.id)
                            } label: {
                                Label(String(localized: "Edit"), systemImage: "pencil")
                            }
                            if !category.isDefault {
                                Button(role: .destructive) {
                                    categoryToDelete = category.id
                                    showingDeleteAlert = true
                                } label: {
                                    Label(String(localized: "Delete"), systemImage: "trash")
                                }
                            }
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
                            NavigationLink {
                                CategoryDetailView(categoryID: category.id)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }

            if !vm.filteredIncomeCategories.isEmpty {
                Section(String(localized: "Income")) {
                    ForEach(vm.filteredIncomeCategories) { category in
                        NavigationLink {
                            CategoryDetailView(categoryID: category.id)
                        } label: {
                            CategoryRowView(category: category)
                        }
                        .accessibilityIdentifier("category-row-\(category.name.lowercased())")
                        .contextMenu {
                            NavigationLink {
                                CategoryDetailView(categoryID: category.id)
                            } label: {
                                Label(String(localized: "Edit"), systemImage: "pencil")
                            }
                            if !category.isDefault {
                                Button(role: .destructive) {
                                    categoryToDelete = category.id
                                    showingDeleteAlert = true
                                } label: {
                                    Label(String(localized: "Delete"), systemImage: "trash")
                                }
                            }
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
