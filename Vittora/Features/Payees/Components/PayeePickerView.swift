import SwiftUI
import VittoraCore

struct PayeePickerView: View {
    @Binding var selectedPayeeID: UUID?
    let payees: [PayeeEntity]
    var title: String = "Select Payee"
    /// Called after a payee is created here, so the host can reload the
    /// `payees` it passed in — this view only receives them.
    var onPayeeCreated: (() -> Void)? = nil

    @State private var searchQuery = ""
    @State private var showAddPayee = false

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

            // With no payees the list was just "None" and a search field, and
            // no way forward. The toolbar button covers every case; this row
            // makes the option findable when the list is otherwise bare.
            if payees.isEmpty {
                Button {
                    showAddPayee = true
                } label: {
                    Label(String(localized: "Add Payee"), systemImage: "plus.circle.fill")
                        .foregroundStyle(VColors.primaryOnSurface)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("payee-picker-add-inline")
            }

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddPayee = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Add Payee"))
                .accessibilityIdentifier("payee-picker-add-button")
            }
        }
        .sheet(isPresented: $showAddPayee) {
            NavigationStack {
                PayeeFormView {
                    onPayeeCreated?()
                }
            }
        }
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
