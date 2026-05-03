import SwiftUI

struct DebtFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.currencySymbol) private var currencySymbol
    @State private var vm: DebtFormViewModel?
    @State private var payees: [PayeeEntity] = []
    let onSaved: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if let vm = vm {
                    Section(String(localized: "Direction")) {
                        Picker(String(localized: "Type"), selection: Bindable(vm).direction) {
                            ForEach(DebtDirection.allCases, id: \.self) { dir in
                                Text(dir.displayName).tag(dir)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(String(localized: "Details")) {
                        Picker(String(localized: "Person / Business"), selection: Bindable(vm).selectedPayeeID) {
                            Text(String(localized: "Select…")).tag(UUID?.none)
                            ForEach(payees) { payee in
                                Text(payee.name).tag(UUID?(payee.id))
                            }
                        }

                        HStack {
                            Text(currencySymbol)
                                .foregroundColor(VColors.textSecondary)
                            TextField(String(localized: "Amount"), text: Bindable(vm).amountString)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                .textContentType(nil)
                                #endif
                        }
                    }

                    Section(String(localized: "Due Date")) {
                        Toggle(String(localized: "Set Due Date"), isOn: Bindable(vm).hasDueDate)
                        if vm.hasDueDate {
                            DatePicker(
                                String(localized: "Due"),
                                selection: Bindable(vm).dueDate,
                                displayedComponents: [.date]
                            )
                        }
                    }

                    Section(String(localized: "Note")) {
                        TextField(String(localized: "Optional note"), text: Bindable(vm).note, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
            }
            .navigationTitle(String(localized: "Add Debt"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        Task {
                            guard let vm else { return }
                            do {
                                try await vm.save()
                                appState.notifyDataChanged()
                                onSaved()
                                dismiss()
                            } catch {
                                vm.error = error.localizedDescription
                            }
                        }
                    }
                    .disabled(!(vm?.canSave ?? false))
                }
            }
        }
        .task {
            guard vm == nil,
                  let debtRepo = dependencies.debtRepository,
                  let payeeRepo = dependencies.payeeRepository else { return }
            let formVM = DebtFormViewModel(createUseCase: CreateDebtEntryUseCase(debtRepository: debtRepo))
            vm = formVM
            do {
                payees = try await payeeRepo.fetchAll()
            } catch {
                formVM.error = error.localizedDescription
            }
        }
    }
}
