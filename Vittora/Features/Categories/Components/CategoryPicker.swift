import SwiftUI

struct CategoryPicker: View {
    @Binding var selectedCategoryID: UUID?
    let categories: [CategoryEntity]
    var filterType: CategoryType? = nil
    var title: String = "Select Category"

    var filteredCategories: [CategoryEntity] {
        if let type = filterType {
            return categories.filter { $0.type == type }
        }
        return categories
    }

    var expenseCategories: [CategoryEntity] {
        filteredCategories.filter { $0.type == .expense }
    }

    var incomeCategories: [CategoryEntity] {
        filteredCategories.filter { $0.type == .income }
    }

    var body: some View {
        List {
            if !expenseCategories.isEmpty && filterType == nil {
                Section("Expense") {
                    categoryRows(expenseCategories)
                }
                Section("Income") {
                    categoryRows(incomeCategories)
                }
            } else {
                Section {
                    categoryRows(filteredCategories)
                }
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func categoryRows(_ cats: [CategoryEntity]) -> some View {
        ForEach(cats) { category in
            Button {
                selectedCategoryID = category.id
            } label: {
                HStack {
                    CategoryRowView(category: category)
                    Spacer()
                    if selectedCategoryID == category.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(VColors.primary)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        CategoryPicker(
            selectedCategoryID: .constant(nil),
            categories: [
                CategoryEntity(name: "Food", icon: "fork.knife", colorHex: "#FF6B35", type: .expense),
                CategoryEntity(name: "Salary", icon: "dollarsign.circle.fill", colorHex: "#34C759", type: .income)
            ]
        )
    }
}
