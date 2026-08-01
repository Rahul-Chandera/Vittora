import SwiftUI
import VittoraCore

struct PayeePickerView: View {
    @Binding var selectedPayeeID: UUID?
    let payees: [PayeeEntity]
    var title: String = "Select Payee"

    @State private var searchQuery = ""

    var filteredPayees: [PayeeEntity] {
        guard !searchQuery.isEmpty else { return payees }
        return payees.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    var body: some View {
        List {
            // None option
            Button {
                selectedPayeeID = nil
            } label: {
                HStack {
                    Text(String(localized: "None"))
                        .font(VTypography.body)
                        .foregroundColor(VColors.textSecondary)
                    Spacer()
                    if selectedPayeeID == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(VColors.primaryOnSurface)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ForEach(filteredPayees) { payee in
                Button {
                    selectedPayeeID = payee.id
                } label: {
                    HStack {
                        PayeeRowView(payee: payee)
                        if selectedPayeeID == payee.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(VColors.primaryOnSurface)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .searchable(text: $searchQuery, prompt: "Search payees")
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #else
        // macOS sheets resize to the pushed view's ideal size; List reports a
        // near-zero ideal height, collapsing the sheet without an explicit min.
        .frame(minWidth: 440, minHeight: 480)
        #endif
    }
}

#Preview {
    NavigationStack {
        PayeePickerView(
            selectedPayeeID: .constant(nil),
            payees: [
                PayeeEntity(name: "Apple Inc.", type: .business),
                PayeeEntity(name: "John Smith", type: .person)
            ]
        )
    }
}
