import SwiftUI
import Charts
import VittoraCore

struct YearInReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm: YearInReviewViewModel?
    @State private var shareURL: URL?
    @State private var isPreparingShare = false
    @State private var showShareFailed = false

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm {
                    if !vm.availableYears.isEmpty {
                        yearPicker(vm)
                    }

                    if vm.isLoading && vm.summary == nil {
                        ProgressView()
                            .tint(VColors.primary)
                            .padding(.top, VSpacing.xxxl)
                            .accessibilityLabel(String(localized: "Loading Year in Review"))
                    } else {
                        switch vm.state {
                        case .thinHistory:
                            thinHistoryState
                        case .emptyYear:
                            emptyYearState
                        case .ready:
                            if let summary = vm.summary {
                                readyContent(summary, vm: vm)
                            } else {
                                emptyYearState
                            }
                        }
                    }
                }
            }
            .padding(VSpacing.screenPadding)
            .animation(reduceMotion ? nil : .default, value: vm?.selectedYear)
        }
        .background(VColors.background)
        .navigationTitle(String(localized: "Year in Review"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let vm, vm.summary != nil {
                    shareButton(vm)
                }
            }
        }
        .task {
            guard vm == nil else { return }
            vm = YearInReviewViewModel(
                useCase: YearInReviewUseCase(
                    transactionRepository: dependencies.transactionRepository,
                    categoryRepository: dependencies.categoryRepository,
                    payeeRepository: dependencies.payeeRepository,
                    savingsGoalRepository: dependencies.savingsGoalRepository
                ),
                preferredCurrencyCode: currencyCode
            )
            await vm?.load()
        }
        .task(id: appState.refreshVersion(for: .transactions)) {
            guard vm != nil, appState.refreshVersion(for: .transactions) > 0 else { return }
            await vm?.load()
        }
        .task(id: appState.refreshVersion(for: .savings)) {
            guard vm != nil, appState.refreshVersion(for: .savings) > 0 else { return }
            await vm?.load()
        }
        .task(id: appState.refreshVersion(for: .categories)) {
            guard vm != nil, appState.refreshVersion(for: .categories) > 0 else { return }
            await vm?.load()
        }
        .task(id: appState.refreshVersion(for: .payees)) {
            guard vm != nil, appState.refreshVersion(for: .payees) > 0 else { return }
            await vm?.load()
        }
        .refreshable { await vm?.load() }
        .errorAlert(message: errorBinding)
        .alert(String(localized: "Share Failed"), isPresented: $showShareFailed) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "We couldn't create the share image. Please try again."))
        }
        .accessibilityIdentifier("year-in-review-root")
    }

    // MARK: - Year picker

    private func yearPicker(_ vm: YearInReviewViewModel) -> some View {
        Picker(String(localized: "Year"), selection: Binding(
            get: { vm.selectedYear ?? vm.availableYears.first ?? Calendar.current.component(.year, from: .now) },
            set: { year in
                Task { await vm.selectYear(year) }
            }
        )) {
            ForEach(vm.availableYears, id: \.self) { year in
                Text(String(localized: "Year \(year)")).tag(year)
            }
        }
        .pickerStyle(.menu)
        .accessibilityLabel(String(localized: "Select year"))
        .accessibilityValue(
            String(localized: "Year \(vm.selectedYear ?? vm.availableYears.first ?? 0)")
        )
        .accessibilityIdentifier("year-in-review-year-picker")
    }

    // MARK: - Ready cards

    @ViewBuilder
    private func readyContent(_ summary: YearInReviewSummary, vm: YearInReviewViewModel) -> some View {
        if summary.scopedToPrimaryCurrency {
            currencyScopeBanner(summary.currencyCode)
        }
        sharePrivacyToggle(vm)
        totalSpentCard(summary)
        topCategoriesCard(summary)
        if let biggest = summary.biggestMonth {
            biggestMonthCard(biggest, currencyCode: summary.currencyCode)
        }
        if !summary.topPayees.isEmpty {
            topPayeesCard(summary)
        }
        savingsCard(summary)
        milestonesCard(summary)
        closingCard(summary)
    }

    private func sharePrivacyToggle(_ vm: YearInReviewViewModel) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Toggle(
                    String(localized: "Include amounts"),
                    isOn: Binding(
                        get: { vm.includeAmountsInShare },
                        set: { newValue in
                            vm.includeAmountsInShare = newValue
                            shareURL = nil
                        }
                    )
                )
                .accessibilityIdentifier("year-in-review-include-amounts")
                .accessibilityHint(String(localized: "When off, the shared image omits money amounts."))
                Text(String(localized: "Off by default so shared images show categories and counts, not your finances."))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier("year-in-review-card-privacy")
    }

    private func currencyScopeBanner(_ code: String) -> some View {
        Text(String(localized: "Showing \(code) only — amounts in other currencies are not combined."))
            .font(VTypography.caption1)
            .foregroundStyle(VColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(VSpacing.md)
            .background(VColors.tertiaryBackground)
            .cornerRadius(VSpacing.cornerRadiusMD)
            .accessibilityIdentifier("year-in-review-currency-scope")
    }

    private func totalSpentCard(_ summary: YearInReviewSummary) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Total spent"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)
                    .accessibilityHidden(true)
                Text(CurrencyFormatter.format(summary.totalSpent, currencyCode: summary.currencyCode))
                    .font(VTypography.amountLarge)
                    .amountScaling()
                    .foregroundStyle(VColors.expense)
                    .accessibilityLabel(String(localized: "Total spent"))
                    .accessibilityValue(
                        CurrencyFormatter.format(summary.totalSpent, currencyCode: summary.currencyCode)
                    )
                    .accessibilityIdentifier("year-in-review-total-spent")

                Chart {
                    ForEach(summary.monthlySpend.filter { $0.amount > 0 }) { point in
                        BarMark(
                            x: .value(String(localized: "Month"), point.monthStart, unit: .month),
                            y: .value(String(localized: "Spent"), point.amount)
                        )
                        .foregroundStyle(VColors.primary)
                        .accessibilityLabel(
                            String(
                                localized: "\(point.monthStart.formatted(.dateTime.month(.wide))) spending"
                            )
                        )
                        .accessibilityValue(
                            CurrencyFormatter.format(point.amount, currencyCode: summary.currencyCode)
                        )
                    }
                }
                .frame(height: 140)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated))
                            }
                        }
                    }
                }
                .accessibilityChartDescriptor(
                    YearInReviewMonthlySpendChartDescriptor(
                        points: summary.monthlySpend,
                        currencyCode: summary.currencyCode
                    )
                )
                .accessibilityIdentifier("year-in-review-month-chart")
            }
        }
        .accessibilityIdentifier("year-in-review-card-total")
    }

    private func topCategoriesCard(_ summary: YearInReviewSummary) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Top categories"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)

                ForEach(summary.topCategories) { category in
                    HStack {
                        VStack(alignment: .leading, spacing: VSpacing.xxs) {
                            Text(category.name)
                                .font(VTypography.bodyBold)
                            Text(String(localized: "\(category.sharePercent)% of spending"))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textSecondary)
                        }
                        Spacer(minLength: VSpacing.sm)
                        Text(CurrencyFormatter.format(category.amount, currencyCode: summary.currencyCode))
                            .font(VTypography.body)
                            .amountScaling()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(
                            localized: "\(category.name), \(CurrencyFormatter.format(category.amount, currencyCode: summary.currencyCode)), \(category.sharePercent) percent"
                        )
                    )
                }
            }
        }
        .accessibilityIdentifier("year-in-review-card-categories")
    }

    private func biggestMonthCard(
        _ highlight: YearInReviewMonthHighlight,
        currencyCode: String
    ) -> some View {
        let monthLabel = highlight.monthStart.formatted(.dateTime.month(.wide).year())
        let amountLabel = CurrencyFormatter.format(highlight.amount, currencyCode: currencyCode)
        let drivenBy: String = {
            guard let name = highlight.topCategoryName else { return "" }
            let drivenAmount = CurrencyFormatter.format(
                highlight.topCategoryAmount,
                currencyCode: currencyCode
            )
            return String(localized: "Driven by \(name), \(drivenAmount)")
        }()
        return VCard {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Text(String(localized: "Biggest month"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)
                Text(highlight.monthStart, format: .dateTime.month(.wide).year())
                    .font(VTypography.title3)
                Text(amountLabel)
                    .font(VTypography.amountMedium)
                    .amountScaling()
                    .foregroundStyle(VColors.expense)
                if let name = highlight.topCategoryName {
                    Text(
                        String(
                            localized: "Driven by \(name) · \(CurrencyFormatter.format(highlight.topCategoryAmount, currencyCode: currencyCode))"
                        )
                    )
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            drivenBy.isEmpty
                ? String(localized: "Biggest month \(monthLabel), \(amountLabel)")
                : String(localized: "Biggest month \(monthLabel), \(amountLabel). \(drivenBy)")
        )
        .accessibilityIdentifier("year-in-review-card-biggest-month")
    }

    private func topPayeesCard(_ summary: YearInReviewSummary) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Top payees"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)
                ForEach(summary.topPayees) { payee in
                    HStack {
                        Text(payee.name)
                            .font(VTypography.body)
                        Spacer()
                        Text(CurrencyFormatter.format(payee.amount, currencyCode: summary.currencyCode))
                            .font(VTypography.body)
                            .amountScaling()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(
                            localized: "\(payee.name), \(CurrencyFormatter.format(payee.amount, currencyCode: summary.currencyCode))"
                        )
                    )
                }
            }
        }
        .accessibilityIdentifier("year-in-review-card-payees")
    }

    private func savingsCard(_ summary: YearInReviewSummary) -> some View {
        let amountLabel = CurrencyFormatter.format(
            summary.savingsContributed,
            currencyCode: summary.currencyCode
        )
        return VCard {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Text(String(localized: "Savings"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)
                Text(amountLabel)
                    .font(VTypography.amountMedium)
                    .amountScaling()
                    .foregroundStyle(VColors.savings)
                Text(String(localized: "\(summary.goalsCompleted) goals completed"))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                localized: "Savings \(amountLabel), \(summary.goalsCompleted) goals completed"
            )
        )
        .accessibilityIdentifier("year-in-review-card-savings")
    }

    private func milestonesCard(_ summary: YearInReviewSummary) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Milestones"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)
                labeledValue(
                    String(localized: "Longest streak"),
                    String(localized: "\(summary.longestStreakDays) days")
                )
                labeledValue(
                    String(localized: "Transactions recorded"),
                    String(localized: "\(summary.transactionCount) transactions")
                )
                if let first = summary.firstTransactionDate {
                    labeledValue(
                        String(localized: "First transaction"),
                        first.formatted(date: .abbreviated, time: .omitted)
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("year-in-review-card-milestones")
    }

    private func closingCard(_ summary: YearInReviewSummary) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Share your year"))
                    .font(VTypography.title3)
                Text(String(localized: "A story-sized image with your highlights. Amounts stay private unless you choose to include them."))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                Text(String(localized: "Year \(String(summary.year)), \(summary.transactionCount) transactions"))
                    .font(VTypography.bodyBold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("year-in-review-card-closing")
    }

    private func labeledValue(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(VTypography.body)
                .foregroundStyle(VColors.textSecondary)
            Spacer()
            Text(value)
                .font(VTypography.bodyBold)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    // MARK: - Empty / thin

    private var thinHistoryState: some View {
        VStack(spacing: VSpacing.md) {
            Image(systemName: "sparkles")
                .font(VTypography.title1)
                .foregroundStyle(VColors.primary)
                .accessibilityHidden(true)
            Text(String(localized: "Your Year in Review is almost ready"))
                .font(VTypography.title3)
                .multilineTextAlignment(.center)
            Text(String(localized: "Keep tracking — once you have about 20 transactions across a couple of months, your Wrapped will be ready to celebrate."))
                .font(VTypography.body)
                .foregroundStyle(VColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(VSpacing.xxxl)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("year-in-review-thin-state")
    }

    private var emptyYearState: some View {
        VStack(spacing: VSpacing.md) {
            Image(systemName: "calendar")
                .font(VTypography.title1)
                .foregroundStyle(VColors.primary)
                .accessibilityHidden(true)
            Text(String(localized: "No activity this year"))
                .font(VTypography.title3)
                .multilineTextAlignment(.center)
            Text(String(localized: "Pick another year with data, or keep logging transactions."))
                .font(VTypography.body)
                .foregroundStyle(VColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(VSpacing.xxxl)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("year-in-review-empty-year")
    }

    // MARK: - Share

    @ViewBuilder
    private func shareButton(_ vm: YearInReviewViewModel) -> some View {
        if let shareURL {
            ShareLink(
                item: shareURL,
                preview: SharePreview(
                    String(localized: "Year in Review"),
                    image: Image(systemName: "sparkles")
                )
            ) {
                Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("year-in-review-share")
        } else {
            Button {
                Task { await prepareShare(vm) }
            } label: {
                if isPreparingShare {
                    ProgressView().controlSize(.small)
                } else {
                    Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
                }
            }
            .disabled(isPreparingShare || vm.summary == nil)
            .accessibilityIdentifier("year-in-review-share")
        }
    }

    @MainActor
    private func prepareShare(_ vm: YearInReviewViewModel) async {
        guard let summary = vm.summary, !isPreparingShare else { return }
        isPreparingShare = true
        defer { isPreparingShare = false }
        do {
            shareURL = try YearInReviewShareImageRenderer.render(
                summary: summary,
                includeAmounts: vm.includeAmountsInShare
            )
        } catch {
            showShareFailed = true
        }
    }

    private var errorBinding: Binding<String?> {
        Binding(
            get: { vm?.error },
            set: { vm?.error = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        YearInReviewView()
    }
}
