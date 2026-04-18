import SwiftUI

struct TaxDashboardView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: TaxEstimateViewModel?
    @State private var showProfileForm = false
    @State private var showBreakdown = false
    @State private var showExportSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                if let vm {
                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                    } else if let estimate = vm.estimate {
                        dashboardContent(vm: vm, estimate: estimate)
                    } else {
                        emptyState
                    }
                }
            }
            .background(VColors.background)
            .navigationTitle(String(localized: "Tax Estimator"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showProfileForm = true
                    } label: {
                        Image(systemName: vm?.estimate == nil ? "plus" : "pencil")
                    }
                }
            }
        }
        .task {
            if vm == nil {
                guard let taxRepo = dependencies.taxProfileRepository else { return }
                let summaryUseCase: GenerateTaxSummaryUseCase? = {
                    guard
                        let transactionRepo = dependencies.transactionRepository,
                        let categoryRepo = dependencies.categoryRepository
                    else {
                        return nil
                    }

                    return GenerateTaxSummaryUseCase(
                        transactionRepository: transactionRepo,
                        fetchTaxCategoriesUseCase: FetchTaxCategoriesUseCase(repository: categoryRepo)
                    )
                }()

                vm = TaxEstimateViewModel(
                    estimateUseCase: EstimateTaxUseCase(),
                    compareUseCase: CompareTaxRegimesUseCase(),
                    saveUseCase: SaveTaxProfileUseCase(taxProfileRepository: taxRepo),
                    summaryUseCase: summaryUseCase,
                    exportService: dependencies.exportService
                )
                await vm?.load()
            }
        }
        .sheet(isPresented: $showProfileForm) {
            TaxProfileFormView(existingProfile: vm?.profile) {
                Task { await vm?.load() }
            }
        }
        .sheet(isPresented: $showBreakdown) {
            if let estimate = vm?.estimate {
                TaxBreakdownView(estimate: estimate)
            }
        }
        .sheet(isPresented: $showExportSheet, onDismiss: {
            vm?.clearExportURL()
        }) {
            if let url = vm?.exportURL {
                ShareSheet(items: [url])
                    .ignoresSafeArea()
            }
        }
        .refreshable {
            await vm?.load()
        }
        .alert(String(localized: "Error"), isPresented: Binding(
            get: { vm?.error != nil },
            set: { if !$0 { vm?.error = nil } }
        )) {
            Button(String(localized: "OK")) { vm?.error = nil }
        } message: {
            Text(vm?.error ?? "")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func dashboardContent(vm: TaxEstimateViewModel, estimate: TaxEstimate) -> some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                // Summary card
                TaxSummaryCard(estimate: estimate)

                // Bracket bar
                VCard {
                    TaxBracketBarView(estimate: estimate)
                }

                // Quick stats grid
                quickStatsGrid(estimate: estimate)

                if let comparison = vm.comparison {
                    TaxComparisonView(comparison: comparison)
                }

                if let summary = vm.summary {
                    TaxAnnualSummaryCard(summary: summary, country: vm.profile.country)
                }

                actionButton(
                    title: String(localized: "Full Bracket Breakdown"),
                    icon: "list.number"
                ) {
                    showBreakdown = true
                }

                actionButton(
                    title: vm.isExporting
                        ? String(localized: "Preparing Tax Report")
                        : String(localized: "Export Tax Report"),
                    icon: "square.and.arrow.up",
                    showsProgress: vm.isExporting
                ) {
                    Task {
                        await vm.exportReport()
                        if vm.exportURL != nil {
                            showExportSheet = true
                        }
                    }
                }
                .disabled(vm.isExporting)

                // Info about regime
                regimeInfoCard(estimate: estimate, profile: vm.profile)

                TaxDisclaimerView()
            }
            .padding(VSpacing.screenPadding)
        }
    }

    private func quickStatsGrid(estimate: TaxEstimate) -> some View {
        let code = estimate.country.currencyCode
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VSpacing.md) {
            StatTile(
                title: String(localized: "Basic Tax"),
                value: estimate.basicTax.formatted(.currency(code: code)),
                icon: "percent",
                color: VColors.expense
            )
            if estimate.rebate > 0 {
                StatTile(
                    title: String(localized: "87A Rebate"),
                    value: "-" + estimate.rebate.formatted(.currency(code: code)),
                    icon: "minus.circle.fill",
                    color: VColors.income
                )
            }
            if estimate.surcharge > 0 {
                StatTile(
                    title: String(localized: "Surcharge"),
                    value: estimate.surcharge.formatted(.currency(code: code)),
                    icon: "arrow.up.circle.fill",
                    color: .orange
                )
            }
            if estimate.cess > 0 {
                StatTile(
                    title: String(localized: "Cess (4%)"),
                    value: estimate.cess.formatted(.currency(code: code)),
                    icon: "cross.circle.fill",
                    color: .purple
                )
            }
            StatTile(
                title: String(localized: "Marginal Rate"),
                value: "\(estimate.marginalRate.formatted(.number.precision(.fractionLength(0))))%",
                icon: "chart.line.uptrend.xyaxis",
                color: VColors.primary
            )
            StatTile(
                title: String(localized: "Effective Rate"),
                value: "\((estimate.effectiveRate * 100).formatted(.number.precision(.fractionLength(1))))%",
                icon: "chart.pie.fill",
                color: VColors.savings
            )
        }
    }

    private func regimeInfoCard(estimate: TaxEstimate, profile: TaxProfile) -> some View {
        HStack(spacing: VSpacing.md) {
            Image(systemName: estimate.country == .india ? "flag.fill" : "building.columns")
                .font(.title2)
                .foregroundStyle(VColors.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text(estimate.country.displayName)
                    .font(VTypography.bodyBold)
                    .foregroundStyle(VColors.textPrimary)
                Text(estimate.regimeLabel + " · " + profile.financialYear)
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
            }
            Spacer()
            Button(String(localized: "Edit")) {
                showProfileForm = true
            }
            .font(VTypography.caption1.bold())
            .foregroundStyle(VColors.primary)
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    private func actionButton(
        title: String,
        icon: String,
        showsProgress: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                if showsProgress {
                    ProgressView()
                        .tint(VColors.primary)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(VColors.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(VSpacing.cardPadding)
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
            .foregroundStyle(VColors.primary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: VSpacing.lg) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 48))
                .foregroundStyle(VColors.textTertiary)
            Text(String(localized: "No Tax Profile"))
                .font(VTypography.bodyBold)
                .foregroundStyle(VColors.textPrimary)
            Text(String(localized: "Set up your income and regime to get an instant tax estimate"))
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "Set Up Profile")) {
                showProfileForm = true
            }
            .buttonStyle(.borderedProminent)
            .tint(VColors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(VSpacing.xxxl)
    }
}

// MARK: - Stat Tile

private struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(VTypography.bodyBold)
                .foregroundStyle(VColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(VTypography.caption2)
                .foregroundStyle(VColors.textSecondary)
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }
}

#Preview {
    TaxDashboardView()
}
