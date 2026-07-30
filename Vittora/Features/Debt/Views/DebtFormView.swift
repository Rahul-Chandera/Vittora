import SwiftUI
import VittoraCore

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
                    Section {
                        Picker(String(localized: "Type"), selection: Bindable(vm).direction) {
                            ForEach(DebtDirection.allCases, id: \.self) { dir in
                                Text(dir.displayName).tag(dir)
                            }
                        }
                        .pickerStyle(.menu)
                    } header: {
                        sectionHeader(String(localized: "Direction"))
                    }
                    .headerProminence(.increased)

                    Section {
                        Picker(String(localized: "Person / Business"), selection: Bindable(vm).selectedPayeeID) {
                            Text(String(localized: "Select…")).tag(UUID?.none)
                            ForEach(payees) { payee in
                                Text(payee.name).tag(UUID?(payee.id))
                            }
                        }

                        HStack {
                            Text(currencySymbol)
                                .foregroundColor(VColors.textPrimary)
                                .accessibilityHidden(true)
                            TextField(
                                "",
                                text: Bindable(vm).amountString,
                                prompt: Text(String(localized: "Amount"))
                                    .foregroundStyle(VColors.textPrimary)
                            )
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                .textContentType(nil)
                                #endif
                                .accessibilityLabel(String(localized: "Debt amount"))
                                .accessibilityHint(String(localized: "Amount in \(currencyCode)"))
                        }
                    } header: {
                        sectionHeader(String(localized: "Details"))
                    }
                    .headerProminence(.increased)

                    Section {
                        Toggle(String(localized: "Set Due Date"), isOn: Bindable(vm).hasDueDate)
                        if vm.hasDueDate {
                            DatePicker(
                                String(localized: "Due"),
                                selection: Bindable(vm).dueDate,
                                displayedComponents: [.date]
                            )
                        }
                    } header: {
                        sectionHeader(String(localized: "Due Date"))
                    }
                    .headerProminence(.increased)

                    Section {
                        TextField(
                            "",
                            text: Bindable(vm).note,
                            prompt: Text(String(localized: "Optional note"))
                                .foregroundStyle(VColors.textPrimary),
                            axis: .vertical
                        )
                            .lineLimit(2...4)
                    } header: {
                        sectionHeader(String(localized: "Note"))
                    }
                    .headerProminence(.increased)
                }
            }
            .tint(VColors.textPrimary)
            .navigationTitle(String(localized: "Add Debt"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        Task {
                            guard let vm else { return }
                            guard vm.canSave else { return }
                            do {
                                try await vm.save()
                                await dependencies.refreshRecurringAndDebtReminders()
                                appState.notifyChanged(.debt)
                                onSaved()
                                dismiss()
                            } catch {
                                vm.error = error.localizedDescription
                            }
                        }
                    }
                    .accessibilityRespondsToUserInteraction(vm?.canSave ?? false)
                    .font(.headline)
                    .foregroundStyle(.primary)
                }
            }
        }
        .task {
            guard vm == nil else { return }
            let formVM = DebtFormViewModel(
                createUseCase: CreateDebtEntryUseCase(debtRepository: dependencies.debtRepository)
            )
            vm = formVM
            do {
                payees = try await dependencies.payeeRepository.fetchAll()
            } catch {
                formVM.error = error.localizedDescription
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        VFormSectionHeader(title)
    }
}
