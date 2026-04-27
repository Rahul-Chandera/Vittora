import SwiftUI

struct TransactionFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: TransactionFilterViewModel
    let onApply: (TransactionFilter) -> Void
    @State private var localVM: TransactionFilterViewModel

    init(viewModel: TransactionFilterViewModel, onApply: @escaping (TransactionFilter) -> Void) {
        _viewModel = State(initialValue: viewModel)
        _localVM = State(initialValue: viewModel)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Date Range")) {
                    Picker(String(localized: "Preset"), selection: Bindable(localVM).datePreset) {
                        ForEach(TransactionFilterViewModel.DatePreset.allCases, id: \.self) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .accessibilityIdentifier("transaction-filter-preset-picker")
                    .onChange(of: localVM.datePreset) { _, newValue in
                        localVM.applyDatePreset(newValue)
                    }

                    if localVM.datePreset == .custom {
                        DatePicker(
                            String(localized: "From"),
                            selection: Binding(
                                get: { localVM.startDate ?? Date.now },
                                set: { localVM.startDate = $0 }
                            ),
                            displayedComponents: [.date]
                        )
                        DatePicker(
                            String(localized: "To"),
                            selection: Binding(
                                get: { localVM.endDate ?? Date.now },
                                set: { localVM.endDate = $0 }
                            ),
                            displayedComponents: [.date]
                        )
                    }
                }

                Section(String(localized: "Transaction Type")) {
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Toggle(type.rawValue.capitalized, isOn: $localVM.selectedTypes.contains(type))
                            .accessibilityIdentifier("transaction-filter-type-\(type.rawValue)")
                    }
                }

                Section(String(localized: "Amount Range")) {
                    TextField(String(localized: "Min"), text: Bindable(localVM).amountMin)
                        .accessibilityIdentifier("transaction-filter-min-field")
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        .textContentType(nil)
                        #endif

                    TextField(String(localized: "Max"), text: Bindable(localVM).amountMax)
                        .accessibilityIdentifier("transaction-filter-max-field")
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        .textContentType(nil)
                        #endif
                }
            }
            .accessibilityIdentifier("transaction-filter-sheet")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Clear")) {
                        localVM.clearAll()
                    }
                    .accessibilityIdentifier("transaction-filter-clear-button")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Apply")) {
                        onApply(localVM.buildFilter())
                        dismiss()
                    }
                    .accessibilityIdentifier("transaction-filter-apply-button")
                }
            }
        }
    }
}

extension Binding where Value: SetAlgebra {
    func contains(_ element: Value.Element) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.wrappedValue.contains(element) },
            set: { newValue in
                var updated = self.wrappedValue
                if newValue {
                    updated.insert(element)
                } else {
                    updated.remove(element)
                }
                self.wrappedValue = updated
            }
        )
    }
}

#Preview {
    TransactionFilterSheet(
        viewModel: TransactionFilterViewModel(),
        onApply: { _ in }
    )
}
