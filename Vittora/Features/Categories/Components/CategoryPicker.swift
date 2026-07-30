import SwiftUI
import VittoraCore

struct CategoryPicker: View {
    @Binding var selectedCategoryID: UUID?
    let categories: [CategoryEntity]
    var filterType: CategoryType? = nil
    var title: String = String(localized: "Select Category")

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
                Section(header: VFormSectionHeader(String(localized: "Expense"))) {
                    categoryRows(expenseCategories)
                }
                Section(header: VFormSectionHeader(String(localized: "Income"))) {
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
        #else
        // A macOS sheet resizes to the pushed view's ideal size, and List
        // reports a near-zero ideal height — without this the whole sheet
        // collapses to a sliver when the picker is pushed inside a form sheet.
        .frame(minWidth: 440, minHeight: 480)
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
                .contentShape(Rectangle())
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
