import SwiftUI

/// Loads a category by ID and presents its edit form.
struct CategoryDetailView: View {
    let categoryID: UUID
    @Environment(\.dependencies) private var dependencies
    @State private var category: CategoryEntity?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let category {
                CategoryFormView(editingCategory: category)
            } else {
                Text("Category not found")
                    .foregroundColor(VColors.textSecondary)
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        let deps = dependencies
        guard let repo = deps.categoryRepository else {
            isLoading = false
            return
        }
        category = try? await repo.fetchByID(categoryID)
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(categoryID: UUID())
    }
}
