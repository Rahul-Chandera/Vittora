import SwiftUI

struct AddGroupExpenseView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.currencySymbol) private var currencySymbol
    @State private var vm: AddGroupExpenseViewModel

    let onSaved: () -> Void

    init(group: SplitGroup, memberNames: [UUID: String], splitGroupRepository: any SplitGroupRepository, onSaved: @escaping () -> Void) {
        _vm = State(initialValue: AddGroupExpenseViewModel(
            group: group,
            memberNames: memberNames,
            addExpenseUseCase: AddGroupExpenseUseCase(splitGroupRepository: splitGroupRepository)
        ))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic details
                Section(String(localized: "Expense")) {
                    TextField(String(localized: "What was it for?"), text: Bindable(vm).title)

                    HStack {
                        Text(currencySymbol).foregroundStyle(VColors.textSecondary)
                        TextField(String(localized: "Amount"), text: Bindable(vm).amountString)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .textContentType(nil)
                            #endif
                            .onChange(of: vm.amountString) { _, _ in vm.recalculate() }
                    }

                    DatePicker(String(localized: "Date"), selection: Bindable(vm).date, displayedComponents: [.date])
                }

                // Payer
                Section(String(localized: "Paid By")) {
                    Picker(String(localized: "Who paid?"), selection: Bindable(vm).selectedPayerID) {
                        Text(String(localized: "Select…")).tag(UUID?.none)
                        ForEach(vm.group.memberIDs, id: \.self) { id in
                            Text(vm.memberNames[id] ?? String(localized: "Unknown")).tag(UUID?(id))
                        }
                    }
                }

                // Split method
                Section(String(localized: "Split Method")) {
                    Picker(String(localized: "Method"), selection: Bindable(vm).splitMethod) {
                        ForEach(SplitMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vm.splitMethod) { _, _ in vm.recalculate() }
                }

                // Allocation rows
                Section {
                    ForEach($vm.allocations) { $row in
                        AllocationRow(
                            row: $row,
                            method: vm.splitMethod,
                            onValueChanged: { vm.recalculate() }
                        )
                    }
                } header: {
                    Text(String(localized: "Splits"))
                } footer: {
                    if vm.splitMethod == .exact {
                        let total = vm.allocations.reduce(Decimal(0)) { $0 + $1.calculatedAmount }
                        let diff = abs(total - vm.amount)
                        if diff > 0.005 && vm.amount > 0 {
                            Text(String(localized: "Remaining: \((vm.amount - total).formatted(.currency(code: currencyCode)))"))
                                .foregroundStyle(VColors.expense)
                        }
                    }
                }

                // Note
                Section(String(localized: "Note")) {
                    TextField(String(localized: "Optional"), text: Bindable(vm).note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let error = vm.error {
                    Section {
                        VInlineErrorText(error)
                    }
                }
            }
            .navigationTitle(String(localized: "Add Expense"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Add")) {
                        Task {
                            let saved = await vm.save()
                            if saved {
                                appState.notifyDataChanged()
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!vm.canSave || vm.isSaving)
                }
            }
        }
        .onChange(of: vm.error) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
            }
        }
    }
}

// MARK: - Allocation Row

private struct AllocationRow: View {
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.currencySymbol) private var currencySymbol
    @Binding var row: MemberAllocationRow
    let method: SplitMethod
    let onValueChanged: () -> Void

    var body: some View {
        HStack {
            Text(row.name)
                .font(VTypography.body)
                .foregroundStyle(VColors.textPrimary)

            Spacer()

            if method == .equal {
                // Read-only calculated amount
                Text(row.calculatedAmount.formatted(.currency(code: currencyCode)))
                    .font(VTypography.body)
                    .foregroundStyle(VColors.textSecondary)
            } else {
                HStack(spacing: 4) {
                    if method == .percentage {
                        TextField("0", text: $row.inputValue)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .textContentType(nil)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onChange(of: row.inputValue) { _, _ in onValueChanged() }
                        Text("%").foregroundStyle(VColors.textSecondary)
                    } else if method == .exact {
                        Text(currencySymbol).foregroundStyle(VColors.textSecondary)
                        TextField("0.00", text: $row.inputValue)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .textContentType(nil)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: row.inputValue) { _, _ in onValueChanged() }
                    } else if method == .shares {
                        TextField("1", text: $row.inputValue)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .textContentType(nil)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 40)
                            .onChange(of: row.inputValue) { _, _ in onValueChanged() }
                        Text(String(localized: "shares")).foregroundStyle(VColors.textSecondary)
                    }
                    Text("=").foregroundStyle(VColors.textSecondary)
                    Text(row.calculatedAmount.formatted(.currency(code: currencyCode)))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
    }
}
