import SwiftUI
import VittoraCore

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
            guard vm == nil else { return }
            let saveUseCase = SaveTaxProfileUseCase(taxProfileRepository: dependencies.taxProfileRepository)
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
        .onChange(of: vm?.error) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
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
                        .textContentType(nil)
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

                    Picker(String(localized: "Income Type"), selection: Bindable(vm).incomeSourceType) {
                        ForEach(IncomeSourceType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .onChange(of: vm.incomeSourceType) { _, _ in vm.recalculateLive() }
                }

                if vm.indiaRegime == .oldRegime {
                    Section {
                        if let dob = vm.dateOfBirth {
                            DatePicker(
                                String(localized: "Date of Birth"),
                                selection: Binding(
                                    get: { dob },
                                    set: { vm.dateOfBirth = $0; vm.recalculateLive() }
                                ),
                                in: ...Date.now,
                                displayedComponents: .date
                            )
                            Button(String(localized: "Clear Date of Birth"), role: .destructive) {
                                vm.dateOfBirth = nil
                                vm.recalculateLive()
                            }
                        } else {
                            Button(String(localized: "Set Date of Birth")) {
                                vm.dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
                                vm.recalculateLive()
                            }
                        }

                        Toggle(String(localized: "Parents are senior citizens (80D)"), isOn: Binding(
                            get: { vm.advancedInputs.indiaParentsSeniorCitizen },
                            set: {
                                vm.advancedInputs.indiaParentsSeniorCitizen = $0
                                vm.recalculateLive()
                            }
                        ))
                    } header: {
                        Text(String(localized: "Age (for senior citizen slabs)"))
                    } footer: {
                        Text(String(localized: "Senior citizens (60+) and super-senior citizens (80+) have higher basic exemption limits under the old regime."))
                    }

                    Section {
                        HStack {
                            Text(vm.country.currencySymbol)
                                .foregroundStyle(VColors.textSecondary)
                            TextField(String(localized: "Annual basic salary + DA"), text: Bindable(vm).indiaBasicSalaryString)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .onChange(of: vm.indiaBasicSalaryString) { _, _ in vm.recalculateLive() }
                        }
                        HStack {
                            Text(vm.country.currencySymbol)
                                .foregroundStyle(VColors.textSecondary)
                            TextField(String(localized: "Annual HRA received"), text: Bindable(vm).indiaHRAPaidString)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .onChange(of: vm.indiaHRAPaidString) { _, _ in vm.recalculateLive() }
                        }
                        HStack {
                            Text(vm.country.currencySymbol)
                                .foregroundStyle(VColors.textSecondary)
                            TextField(String(localized: "Annual rent paid"), text: Bindable(vm).indiaRentPaidString)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .onChange(of: vm.indiaRentPaidString) { _, _ in vm.recalculateLive() }
                        }
                        Toggle(String(localized: "Metro city"), isOn: Binding(
                            get: { vm.advancedInputs.indiaMetroCity },
                            set: {
                                vm.advancedInputs.indiaMetroCity = $0
                                vm.recalculateLive()
                            }
                        ))
                    } header: {
                        Text(String(localized: "HRA Exemption"))
                    } footer: {
                        Text(String(localized: "HRA exemption uses the minimum of actual HRA, rent minus 10% of salary, and 50%/40% of salary."))
                    }
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

                Section {
                    contributionAmountField(
                        vm: vm,
                        title: String(localized: "401(k) contributed YTD"),
                        text: Bindable(vm).us401kContributedString,
                        currencyCode: vm.country.currencyCode
                    )
                    contributionAmountField(
                        vm: vm,
                        title: String(localized: "IRA contributed YTD"),
                        text: Bindable(vm).usIRAContributedString,
                        currencyCode: vm.country.currencyCode
                    )
                    contributionAmountField(
                        vm: vm,
                        title: String(localized: "HSA contributed YTD"),
                        text: Bindable(vm).usHSAContributedString,
                        currencyCode: vm.country.currencyCode
                    )
                    Toggle(String(localized: "HSA family coverage"), isOn: Binding(
                        get: { vm.advancedInputs.usHSAFamilyCoverage },
                        set: {
                            vm.advancedInputs.usHSAFamilyCoverage = $0
                            vm.recalculateLive()
                        }
                    ))
                } header: {
                    Text(String(localized: "Retirement & HSA Contributions"))
                } footer: {
                    Text(String(localized: "Track year-to-date contributions to see remaining statutory headroom in your estimate."))
                }

                if !vm.usContributionUtilization.isEmpty {
                    Section(String(localized: "Contribution Headroom")) {
                        ForEach(vm.usContributionUtilization) { item in
                            VStack(alignment: .leading, spacing: VSpacing.sm) {
                                HStack {
                                    Text(item.title)
                                    Spacer()
                                    Text(
                                        "\(item.contributed.formatted(.currency(code: vm.country.currencyCode))) / \(item.statutoryLimit.formatted(.currency(code: vm.country.currencyCode)))"
                                    )
                                    .font(VTypography.caption1.bold())
                                }
                                ProgressView(value: item.utilizationFraction)
                                    .tint(item.headroom > 0 ? VColors.primary : VColors.warning)
                                Text(
                                    String(
                                        localized: "\(item.headroom.formatted(.currency(code: vm.country.currencyCode))) remaining"
                                    )
                                )
                                .font(VTypography.caption2)
                                .foregroundStyle(VColors.textSecondary)
                            }
                        }
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

                if let utilization = vm.section80CUtilization {
                    Section(String(localized: "Section 80C Utilization")) {
                        VStack(alignment: .leading, spacing: VSpacing.sm) {
                            HStack {
                                Text(String(localized: "Used"))
                                Spacer()
                                Text(
                                    "\(utilization.allowed.formatted(.currency(code: vm.country.currencyCode))) / \(utilization.statutoryCap.formatted(.currency(code: vm.country.currencyCode)))"
                                )
                                .font(VTypography.bodyBold)
                            }
                            ProgressView(value: Double(truncating: (utilization.allowed / utilization.statutoryCap) as NSDecimalNumber))
                                .tint(VColors.primary)
                            if utilization.claimed > utilization.allowed {
                                Text(String(localized: "Claims above ₹1.5 lakh are capped for tax calculation."))
                                    .font(VTypography.caption1)
                                    .foregroundStyle(VColors.warning)
                            }
                        }
                    }
                }

                if vm.indiaDeductionUtilization.count > 1 {
                    Section(String(localized: "Section Caps")) {
                        ForEach(vm.indiaDeductionUtilization.filter { $0.sectionKey != "80C" }) { item in
                            HStack {
                                Text(item.sectionKey)
                                Spacer()
                                Text(
                                    "\(item.allowed.formatted(.currency(code: vm.country.currencyCode))) / \(item.statutoryCap.formatted(.currency(code: vm.country.currencyCode)))"
                                )
                                .font(VTypography.caption1)
                            }
                        }
                    }
                }
            }

            // Live estimate preview
            if let live = vm.liveEstimate {
                Section(String(localized: "Live Estimate")) {
                    if vm.country == .unitedStates {
                        USTaxFederalEstimateLabel()
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
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
                    VInlineErrorText(error)
                }
            }

            Section {
                TaxDisclaimerView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder
    private func contributionAmountField(
        vm: TaxProfileFormViewModel,
        title: String,
        text: Binding<String>,
        currencyCode: String
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(String.currencySymbol(for: currencyCode))
                .foregroundStyle(VColors.textSecondary)
            TextField("0", text: text)
                #if os(iOS)
                .keyboardType(.decimalPad)
                .textContentType(nil)
                #endif
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
                .onChange(of: text.wrappedValue) { _, _ in
                    vm.recalculateLive()
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

    private var parsedAmount: Decimal? { Decimal(localizedAmount: amountString) }
    private var canAdd: Bool {
        guard let parsedAmount, parsedAmount > 0 else { return false }
        return !name.isEmpty
    }

    private var indiaSections: [String] {
        ["80C", "80CCD(1B)", "80D", "80D (Parents)", "HRA"]
    }

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
                            .textContentType(nil)
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
                        if let parsedAmount {
                            onAdd(name, parsedAmount, section.isEmpty ? nil : section)
                        }
                    }
                    .disabled(!canAdd)
                }
            }
        }
    }
}
