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
                Section("Date Range") {
                    Picker("Preset", selection: Bindable(localVM).datePreset) {
                        ForEach(TransactionFilterViewModel.DatePreset.allCases, id: \.self) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .onChange(of: localVM.datePreset) { _, newValue in
                        localVM.applyDatePreset(newValue)
                    }

                    if localVM.datePreset == .custom {
                        DatePicker(
                            "From",
                            selection: Binding(
                                get: { localVM.startDate ?? Date.now },
                                set: { localVM.startDate = $0 }
                            ),
                            displayedComponents: [.date]
                        )
                        DatePicker(
                            "To",
                            selection: Binding(
                                get: { localVM.endDate ?? Date.now },
                                set: { localVM.endDate = $0 }
                            ),
                            displayedComponents: [.date]
                        )
                    }
                }

                Section("Transaction Type") {
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Toggle(type.rawValue.capitalized, isOn: $localVM.selectedTypes.contains(type))
                    }
                }

                Section("Amount Range") {
                    TextField("Min", text: Bindable(localVM).amountMin)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif

                    TextField("Max", text: Bindable(localVM).amountMax)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        localVM.clearAll()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(localVM.buildFilter())
                        dismiss()
                    }
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
