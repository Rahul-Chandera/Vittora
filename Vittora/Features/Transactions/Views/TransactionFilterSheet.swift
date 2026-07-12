import SwiftUI
import VittoraCore

struct TransactionFilterSheet: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: TransactionFilterViewModel
    let onApply: (TransactionFilter) -> Void
    @State private var localVM: TransactionFilterViewModel
    @State private var savedPresets: [SavedTransactionFilterPreset] = []
    @State private var showSaveAlert = false
    @State private var presetName = ""
    @State private var filterError: String?

    init(viewModel: TransactionFilterViewModel, onApply: @escaping (TransactionFilter) -> Void) {
        _viewModel = State(initialValue: viewModel)
        _localVM = State(initialValue: viewModel)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                if !savedPresets.isEmpty {
                    Section(String(localized: "Saved Filters")) {
                        ForEach(savedPresets) { preset in
                            Button {
                                localVM.applySnapshot(preset.snapshot)
                            } label: {
                                HStack {
                                    Text(preset.name)
                                        .foregroundColor(VColors.textPrimary)
                                    Spacer()
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .foregroundColor(VColors.textSecondary)
                                }
                            }
                            .accessibilityIdentifier("saved-filter-\(preset.id.uuidString)")
                            .swipeActions {
                                Button(role: .destructive) {
                                    deletePreset(preset)
                                } label: {
                                    Label(String(localized: "Delete"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }

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
                        Toggle(type.displayName, isOn: $localVM.selectedTypes.contains(type))
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
            .navigationTitle(String(localized: "Filters"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Clear")) {
                        localVM.clearAll()
                    }
                    .accessibilityIdentifier("transaction-filter-clear-button")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(String(localized: "Save")) {
                        presetName = ""
                        showSaveAlert = true
                    }
                    .accessibilityIdentifier("transaction-filter-save-button")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Apply")) {
                        onApply(localVM.buildFilter())
                        dismiss()
                    }
                    .accessibilityIdentifier("transaction-filter-apply-button")
                }
            }
            .alert(String(localized: "Save Filter"), isPresented: $showSaveAlert) {
                TextField(String(localized: "Name"), text: $presetName)
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Save")) {
                    saveCurrentFilter()
                }
            } message: {
                Text(String(localized: "Save the current filter settings for quick access later."))
            }
            .errorAlert(message: $filterError)
            .task {
                reloadSavedPresets()
            }
        }
    }

    private func reloadSavedPresets() {
        do {
            savedPresets = try dependencies.makeManageSavedTransactionFiltersUseCase().fetchAll()
        } catch {
            savedPresets = []
            filterError = error.userFacingMessage(
                fallback: String(localized: "We couldn't load saved filters.")
            )
        }
    }

    private func saveCurrentFilter() {
        do {
            _ = try dependencies.makeManageSavedTransactionFiltersUseCase().save(
                name: presetName,
                snapshot: localVM.makeSnapshot()
            )
            reloadSavedPresets()
        } catch {
            filterError = error.userFacingMessage(
                fallback: String(localized: "We couldn't save this filter.")
            )
        }
    }

    private func deletePreset(_ preset: SavedTransactionFilterPreset) {
        do {
            try dependencies.makeManageSavedTransactionFiltersUseCase().delete(id: preset.id)
            reloadSavedPresets()
        } catch {
            filterError = error.userFacingMessage(
                fallback: String(localized: "We couldn't delete this filter.")
            )
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
