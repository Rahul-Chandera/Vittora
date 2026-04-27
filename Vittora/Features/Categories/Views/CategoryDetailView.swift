import SwiftUI

/// Loads a category by ID and presents its edit form.
struct CategoryDetailView: View {
    let categoryID: UUID
    @Environment(\.dependencies) private var dependencies
    @State private var category: CategoryEntity?
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let loadError {
                Text(loadError)
                    .foregroundColor(VColors.expense)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if let category {
                CategoryFormView(editingCategory: category)
            } else {
                Text(String(localized: "Category not found"))
                    .foregroundColor(VColors.textSecondary)
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        let deps = dependencies
        guard let repo = deps.categoryRepository else {
            isLoading = false
            return
        }
        do {
            category = try await repo.fetchByID(categoryID)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(categoryID: UUID())
    }
}
