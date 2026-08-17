import SwiftUI
import VittoraCore

struct AddGroupExpenseView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
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
                Section {
                    TextField(String(localized: "Expense title"), text: Bindable(vm).title)
                        .accessibilityLabel(String(localized: "Expense title"))

                    HStack {
                        TextField(String(localized: "Amount"), text: Bindable(vm).amountString)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .textContentType(nil)
                            #endif
                            .accessibilityLabel(String(localized: "Expense amount"))
                            .accessibilityHint(String(localized: "Amount in \(currencyCode)"))
                            .onChange(of: vm.amountString) { _, _ in vm.recalculate() }
                    }

                    DatePicker(String(localized: "Date"), selection: Bindable(vm).date, displayedComponents: [.date])
                } header: {
                    sectionHeader(String(localized: "Expense"))
                }
                .headerProminence(.increased)

                // Payer
                Section {
                    Picker(String(localized: "Who paid?"), selection: Bindable(vm).selectedPayerID) {
                        Text(String(localized: "Select…")).tag(UUID?.none)
                        ForEach(vm.group.memberIDs, id: \.self) { id in
                            Text(vm.memberNames[id] ?? String(localized: "Unknown")).tag(UUID?(id))
                        }
                    }
                } header: {
                    sectionHeader(String(localized: "Paid By"))
                }
                .headerProminence(.increased)

                // Split method
                Section {
                    Picker(String(localized: "Method"), selection: Bindable(vm).splitMethod) {
                        ForEach(SplitMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: vm.splitMethod) { _, _ in vm.recalculate() }
                } header: {
                    sectionHeader(String(localized: "Split Method"))
                }
                .headerProminence(.increased)

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
                    sectionHeader(String(localized: "Splits"))
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
                .headerProminence(.increased)

                // Note
                Section {
                    TextField(String(localized: "Optional"), text: Bindable(vm).note, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    sectionHeader(String(localized: "Note"))
                }
                .headerProminence(.increased)

                if let error = vm.error {
                    Section {
                        VInlineErrorText(error)
                    }
                }
            }
            .tint(VColors.textPrimary)
            .navigationTitle(String(localized: "Add Expense"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .font(.body)
                        .foregroundStyle(VColors.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Add")) {
                        guard vm.canSave, !vm.isSaving else { return }
                        Task {
                            let saved = await vm.save()
                            if saved {
                                dependencies.conversionEventRecorder.afterSplitExpenseCreated()
                                // .budgets too: a group expense writes an expense transaction,
                                // so any budget covering its category is now stale.
                                appState.notifyChanged([.splits, .transactions, .accounts, .budgets])
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .font(.body)
                    .accessibilityRespondsToUserInteraction(vm.canSave && !vm.isSaving)
                    .foregroundStyle(VColors.textPrimary)
                }
            }
        }
        .onChange(of: vm.error) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        VFormSectionHeader(title)
    }
}

// MARK: - Allocation Row

private struct AllocationRow: View {
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.currencySymbol) private var currencySymbol
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var row: MemberAllocationRow
    let method: SplitMethod
    let onValueChanged: () -> Void

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.xs))
            : AnyLayout(HStackLayout())
        layout {
            Text(row.name)
                .font(VTypography.body)
                .foregroundStyle(VColors.textPrimary)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            if method == .equal {
                // Read-only calculated amount
                Text(row.calculatedAmount.formatted(.currency(code: currencyCode)))
                    .font(VTypography.bodyBold)
                    .foregroundStyle(.primary)
            } else {
                HStack(spacing: 4) {
                    if method == .percentage {
                        TextField("", text: $row.inputValue, prompt: Text("0").foregroundStyle(VColors.placeholderText))
                            .accessibilityLabel(String(localized: "Percentage share"))
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
                        TextField("", text: $row.inputValue, prompt: Text("0.00").foregroundStyle(VColors.placeholderText))
                            .accessibilityLabel(String(localized: "Exact amount"))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .textContentType(nil)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: row.inputValue) { _, _ in onValueChanged() }
                    } else if method == .shares {
                        TextField("", text: $row.inputValue, prompt: Text("1").foregroundStyle(VColors.placeholderText))
                            .accessibilityLabel(String(localized: "Shares"))
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.name)
        .accessibilityValue(row.calculatedAmount.formatted(.currency(code: currencyCode)))
    }
}
