import SwiftUI
import VittoraCore

struct TaxDashboardView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var vm: TaxEstimateViewModel?
    @State private var showProfileForm = false
    @State private var breakdownPresentation: TaxBreakdownPresentation?
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
            // Fill first, then paint. A ZStack sizes to its child, so the page
            // colour only covered the empty state's own height and left white
            // above and below it.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VColors.groupedBackground)
            .navigationTitle(String(localized: "Tax Estimator"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showProfileForm = true
                    } label: {
                        Image(systemName: vm?.estimate == nil ? "plus" : "pencil")
                    }
                    .accessibilityLabel(
                        vm?.estimate == nil
                        ? String(localized: "Set up tax profile")
                        : String(localized: "Edit tax profile")
                    )
                    .accessibilityHint(String(localized: "Opens the tax profile form"))
                    .accessibilityIdentifier("tax-profile-button")
                }
            }
        }
        .task {
            if vm == nil {
                let summaryUseCase = GenerateTaxSummaryUseCase(
                    transactionRepository: dependencies.transactionRepository,
                    fetchTaxCategoriesUseCase: FetchTaxCategoriesUseCase(repository: dependencies.categoryRepository)
                )

                vm = TaxEstimateViewModel(
                    estimateUseCase: EstimateTaxUseCase(),
                    compareUseCase: CompareTaxRegimesUseCase(),
                    saveUseCase: SaveTaxProfileUseCase(taxProfileRepository: dependencies.taxProfileRepository),
                    summaryUseCase: summaryUseCase,
                    complianceTipsUseCase: EvaluateIndiaComplianceTipsUseCase(
                        transactionRepository: dependencies.transactionRepository,
                        accountRepository: dependencies.accountRepository,
                        categoryRepository: dependencies.categoryRepository
                    ),
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
        .sheet(item: $breakdownPresentation) { presentation in
            TaxBreakdownView(estimate: presentation.estimate)
        }
        .sheet(isPresented: $showExportSheet, onDismiss: {
            Task { await vm?.cleanupExport() }
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

                IndiaComplianceTipsSection(tips: vm.complianceTips) { tip in
                    vm.dismissComplianceTip(tip)
                }

                actionButton(
                    title: String(localized: "Full Bracket Breakdown"),
                    icon: "list.number"
                ) {
                    breakdownPresentation = TaxBreakdownPresentation(estimate: estimate)
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
        // Clearance for the floating tab bar. safeAreaPadding, not
        // safeAreaInset: this screen is a stack of cards, and an opaque inset
        // paints OVER the last one, slicing it mid-glyph — which the audit's
        // contrast sampler reads as failing text. Padding reserves the same
        // space without drawing.
        //
        // Dashboard and the report screens keep their inset: they are the ones
        // where removing it lets content render in the gutter below the tab
        // bar, which the audit reports as text with no accessible element.
        .safeAreaPadding(.bottom, dynamicTypeSize.isAccessibilitySize ? 140 : 72)
    }

    private func quickStatsGrid(estimate: TaxEstimate) -> some View {
        let code = estimate.country.currencyCode
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: VSpacing.md) {
            StatTile(
                title: String(localized: "Basic Tax"),
                value: estimate.basicTax.formatted(.currency(code: code)),
                icon: "percent"
            )
            if estimate.rebate > 0 {
                StatTile(
                    title: String(localized: "87A Rebate"),
                    value: "-" + estimate.rebate.formatted(.currency(code: code)),
                    icon: "minus.circle.fill"
                )
            }
            if estimate.surcharge > 0 {
                StatTile(
                    title: String(localized: "Surcharge"),
                    value: estimate.surcharge.formatted(.currency(code: code)),
                    icon: "arrow.up.circle.fill"
                )
            }
            if estimate.cess > 0 {
                StatTile(
                    title: String(localized: "Cess (4%)"),
                    value: estimate.cess.formatted(.currency(code: code)),
                    icon: "cross.circle.fill"
                )
            }
            StatTile(
                title: String(localized: "Marginal Rate"),
                value: "\(estimate.marginalRate.formatted(.number.precision(.fractionLength(0))))%",
                icon: "chart.line.uptrend.xyaxis"
            )
            StatTile(
                title: String(localized: "Effective Rate"),
                value: "\((estimate.effectiveRate * 100).formatted(.number.precision(.fractionLength(1))))%",
                icon: "chart.pie.fill"
            )
        }
    }

    private func regimeInfoCard(estimate: TaxEstimate, profile: TaxProfile) -> some View {
        HStack(spacing: VSpacing.md) {
            Image(systemName: estimate.country == .india ? "flag.fill" : "building.columns")
                .font(.title2)
                .foregroundStyle(VColors.textPrimary)
                .accessibilityHidden(true)
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
            .foregroundStyle(VColors.textPrimary)
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryGroupedBackground)
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
                        .accessibilityHidden(true)
                }
                Text(title)
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.primary)
                    .accessibilityHidden(true)
            }
            .padding(VSpacing.cardPadding)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .background(VColors.secondaryGroupedBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(String(localized: "Opens the detail screen"))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: VSpacing.lg) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 48))
                .foregroundStyle(VColors.textTertiary)
                .accessibilityHidden(true)
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

// MARK: - Breakdown presentation

private struct TaxBreakdownPresentation: Identifiable {
    let id = UUID()
    let estimate: TaxEstimate
}

// MARK: - Stat Tile

private struct StatTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let value: String
    let icon: String

    private var highContrastText: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(highContrastText)
                    .accessibilityHidden(true)
                Spacer()
            }
            Text(value)
                .font(VTypography.bodyBold)
                .foregroundStyle(highContrastText)
                .fixedSize(horizontal: false, vertical: true)
            Text(title)
                .font(VTypography.bodyBold)
                .foregroundStyle(highContrastText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(VSpacing.cardPadding)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(VColors.secondaryGroupedBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

#Preview {
    TaxDashboardView()
}
