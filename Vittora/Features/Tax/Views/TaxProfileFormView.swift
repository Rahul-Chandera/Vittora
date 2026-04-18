import SwiftUI

struct TaxProfileFormView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var vm: TaxProfileFormViewModel?

    let existingProfile: TaxProfile?
    let onSaved: () -> Void

    init(existingProfile: TaxProfile? = nil, onSaved: @escaping () -> Void) {
        self.existingProfile = existingProfile
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    formContent(vm)
                } else {
                    ProgressView().tint(VColors.primary)
                }
            }
            .navigationTitle(String(localized: "Tax Profile"))
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
                                onSaved()
                                dismiss()
                            } catch {
                                if vm.error == nil {
                                    vm.error = error.userFacingMessage(
                                        fallback: String(localized: "We couldn't save this tax profile right now.")
                                    )
                                }
                            }
                        }
                    }
                    .disabled(!(vm?.canSave ?? false) || (vm?.isSaving ?? false))
                }
            }
        }
        .task {
            guard vm == nil, let taxRepo = dependencies.taxProfileRepository else { return }
            let saveUseCase = SaveTaxProfileUseCase(taxProfileRepository: taxRepo)
            let estimateUseCase = EstimateTaxUseCase()
            let newVM = TaxProfileFormViewModel(
                saveUseCase: saveUseCase,
                estimateUseCase: estimateUseCase,
                compareUseCase: CompareTaxRegimesUseCase()
            )
            vm = newVM
            if let profile = existingProfile {
                newVM.populate(from: profile)
            }
        }
    }

    @ViewBuilder
    private func formContent(_ vm: TaxProfileFormViewModel) -> some View {
        @Bindable var bindableVM = vm
        Form {
            // Country
            Section(String(localized: "Country")) {
                Picker(String(localized: "Country"), selection: Bindable(vm).country) {
                    ForEach(TaxCountry.allCases, id: \.self) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                .onChange(of: vm.country) { _, _ in
                    vm.financialYear = vm.country.defaultFinancialYear
                    vm.recalculateLive()
                }
            }

            // Income
            Section(String(localized: "Annual Income")) {
                HStack {
                    Text(vm.country.currencySymbol)
                        .foregroundStyle(VColors.textSecondary)
                    TextField(String(localized: "e.g. 1200000"), text: Bindable(vm).incomeString)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .onChange(of: vm.incomeString) { _, _ in vm.recalculateLive() }
                }

                Text(String(localized: "Financial Year: \(vm.financialYear)"))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
            }

            // Regime / Filing Status
            if vm.country == .india {
                Section(String(localized: "Tax Regime")) {
                    Picker(String(localized: "Regime"), selection: Bindable(vm).indiaRegime) {
                        ForEach(IndiaRegime.allCases, id: \.self) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vm.indiaRegime) { _, _ in vm.recalculateLive() }
                }
            } else {
                Section {
                    Picker(String(localized: "Status"), selection: Bindable(vm).filingStatus) {
                        ForEach(USFilingStatus.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .onChange(of: vm.filingStatus) { _, _ in vm.recalculateLive() }
                } header: {
                    Text(String(localized: "Filing Status"))
                } footer: {
                    if vm.filingStatus == .qualifyingSurvivingSpouse {
                        Text(
                            String(localized: "Use this status only during the two tax years after a spouse's death if you still meet IRS eligibility requirements.")
                        )
                    }
                }
            }

            // Deductions (old regime India or itemized US)
            let showDeductions = vm.country == .unitedStates || vm.indiaRegime == .oldRegime
            if showDeductions {
                Section {
                    ForEach($bindableVM.customDeductions) { $deduction in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(deduction.name)
                                    .font(VTypography.body)
                                if let section = deduction.section {
                                    Text(section)
                                        .font(VTypography.caption1)
                                        .foregroundStyle(VColors.primary)
                                }
                            }
                            Spacer()
                            Text(deduction.amount.formatted(.currency(code: vm.country.currencyCode)))
                                .font(VTypography.bodyBold)
                                .foregroundStyle(VColors.income)
                        }
                    }
                    .onDelete { offsets in vm.removeDeduction(at: offsets) }
                } header: {
                    Text(String(localized: "Deductions"))
                } footer: {
                    AddDeductionFooter(country: vm.country, onAdd: { name, amount, section in
                        vm.addDeduction(name: name, amount: amount, section: section)
                    })
                }
            }

            // Live estimate preview
            if let live = vm.liveEstimate {
                Section(String(localized: "Live Estimate")) {
                    HStack {
                        Text(String(localized: "Estimated Tax"))
                        Spacer()
                        Text(live.finalTax.formatted(.currency(code: vm.country.currencyCode)))
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.expense)
                    }
                    HStack {
                        Text(String(localized: "Effective Rate"))
                        Spacer()
                        Text((live.effectiveRate * 100).formatted(.number.precision(.fractionLength(1))) + "%")
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.textPrimary)
                    }
                }
            }

            if let comparison = vm.liveComparison {
                Section(String(localized: "Live Comparison")) {
                    TaxComparisonView(comparison: comparison)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            if let error = vm.error {
                Section {
                    Text(error)
                        .foregroundStyle(VColors.expense)
                        .font(VTypography.caption1)
                }
            }

            Section {
                TaxDisclaimerView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }
}

// MARK: - Add Deduction Footer

private struct AddDeductionFooter: View {
    let country: TaxCountry
    let onAdd: (String, Decimal, String?) -> Void

    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Label(String(localized: "Add Deduction"), systemImage: "plus.circle")
        }
        .sheet(isPresented: $showSheet) {
            AddDeductionSheet(country: country, onAdd: { name, amount, section in
                onAdd(name, amount, section)
                showSheet = false
            })
        }
    }
}

private struct AddDeductionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let country: TaxCountry
    let onAdd: (String, Decimal, String?) -> Void

    @State private var name = ""
    @State private var amountString = ""
    @State private var section = ""

    private var amount: Decimal { Decimal(string: amountString) ?? 0 }
    private var canAdd: Bool { !name.isEmpty && amount > 0 }

    private var indiaSections: [String] { ["80C", "80D", "80E", "80G", "HRA", "LTA", "Other"] }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Name")) {
                    TextField(String(localized: "e.g. Life Insurance Premium"), text: $name)
                }
                if country == .india {
                    Section(String(localized: "Section")) {
                        Picker(String(localized: "Section"), selection: $section) {
                            Text(String(localized: "None")).tag("")
                            ForEach(indiaSections, id: \.self) { s in Text(s).tag(s) }
                        }
                    }
                }
                Section(String(localized: "Amount")) {
                    HStack {
                        Text(country.currencySymbol).foregroundStyle(VColors.textSecondary)
                        TextField("0", text: $amountString)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                }
            }
            .navigationTitle(String(localized: "Add Deduction"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Add")) {
                        onAdd(name, amount, section.isEmpty ? nil : section)
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }
}
