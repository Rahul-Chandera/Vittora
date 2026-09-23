import SwiftUI
import VittoraCore

/// Month-end projection (M3.2.2) and what-if scenarios (M3.2.5).
///
/// Both are extrapolations from the user's own records, and both say so. The
/// plan's scope note rules out financial advice, so nothing here recommends a
/// change — the what-if section answers "what would that have been worth",
/// with the category and the percentage both chosen by the user.
struct SpendingOutlookReportView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: SpendingOutlookViewModel?

    private let currencyCode: String

    init(currencyCode: String = CurrencyDefaults.code) {
        self.currencyCode = currencyCode
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VSpacing.sectionSpacing) {
                if let vm {
                    if vm.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        projectionSection(vm)
                        whatIfSection(vm)
                    }
                    if let error = vm.error {
                        Text(error)
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textPrimary)
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VColors.groupedBackground)
        .navigationTitle(String(localized: "Spending Outlook"))
        .task {
            if vm == nil {
                vm = SpendingOutlookViewModel(
                    transactionRepository: dependencies.transactionRepository,
                    categoryRepository: dependencies.categoryRepository
                )
            }
            await vm?.load()
        }
    }

    // MARK: - M3.2.2

    @ViewBuilder
    private func projectionSection(_ vm: SpendingOutlookViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            Text(String(localized: "This Month"))
                .font(VTypography.subheadline)
                .foregroundStyle(VColors.textSecondary)

            VCard {
                if let projection = vm.projection {
                    VStack(alignment: .leading, spacing: VSpacing.sm) {
                        Text(String(localized: "On track for"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                        Text(projection.projectedTotal.formatted(.currency(code: currencyCode)))
                            .font(VTypography.amountLarge)
                            .foregroundStyle(VColors.textPrimary)
                            .monospacedDigit()
                            .accessibilityIdentifier("outlook-projected-total")

                        Text(String(localized: "\(projection.spentSoFar.formatted(.currency(code: currencyCode))) spent over \(projection.elapsedDays) of \(projection.totalDays) days."))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Only shown when there is a basis for it. Without prior
                        // months there is nothing to compare against, and
                        // comparing with zero would call every month an overspend.
                        if let typical = projection.typicalMonth,
                           let difference = projection.differenceFromTypical {
                            Divider()
                            HStack {
                                Text(String(localized: "Typical month"))
                                    .font(VTypography.caption1)
                                    .foregroundStyle(VColors.textSecondary)
                                Spacer()
                                Text(typical.formatted(.currency(code: currencyCode)))
                                    .font(VTypography.caption1)
                                    .foregroundStyle(VColors.textSecondary)
                                    .monospacedDigit()
                            }
                            Text(projection.isAboveTypical
                                 ? String(localized: "That is \(abs(difference).formatted(.currency(code: currencyCode))) above your usual.")
                                 : String(localized: "That is \(abs(difference).formatted(.currency(code: currencyCode))) below your usual."))
                                .font(VTypography.caption1)
                                .foregroundStyle(projection.isAboveTypical ? VColors.warning : VColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider()
                        ForEach(SpendingProjectionEngine.caveats, id: \.self) { caveat in
                            Text(caveat)
                                .font(VTypography.caption2)
                                .foregroundStyle(VColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    Text(String(localized: "Not enough of the month has passed to estimate a total yet."))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - M3.2.5

    @ViewBuilder
    private func whatIfSection(_ vm: SpendingOutlookViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            Text(String(localized: "What If"))
                .font(VTypography.subheadline)
                .foregroundStyle(VColors.textSecondary)

            VCard {
                if vm.categories.isEmpty {
                    Text(String(localized: "A category needs a couple of months of history before it can be modelled."))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: VSpacing.md) {
                        Picker(String(localized: "Category"), selection: Bindable(vm).selectedCategoryID) {
                            ForEach(vm.categories, id: \.id) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                        .accessibilityIdentifier("outlook-category-picker")

                        VStack(alignment: .leading, spacing: VSpacing.xs) {
                            HStack {
                                Text(String(localized: "Reduce by"))
                                    .font(VTypography.body)
                                Spacer()
                                Text("\((vm.reductionPercent as NSDecimalNumber).intValue)%")
                                    .font(VTypography.bodyBold)
                                    .monospacedDigit()
                            }
                            Slider(
                                value: Binding(
                                    get: { (vm.reductionPercent as NSDecimalNumber).doubleValue },
                                    set: { vm.reductionPercent = Decimal($0).rounded(scale: 0) }
                                ),
                                in: 5...100,
                                step: 5
                            )
                            .accessibilityIdentifier("outlook-reduction-slider")
                            .accessibilityValue(Text("\((vm.reductionPercent as NSDecimalNumber).intValue)%"))
                        }

                        if let scenario = vm.scenario {
                            Divider()
                            HStack {
                                Text(String(localized: "Each month"))
                                    .font(VTypography.body)
                                Spacer()
                                Text(scenario.monthlySaving.formatted(.currency(code: currencyCode)))
                                    .font(VTypography.bodyBold)
                                    .monospacedDigit()
                            }
                            HStack {
                                Text(String(localized: "Over a year"))
                                    .font(VTypography.body)
                                Spacer()
                                Text(scenario.annualSaving.formatted(.currency(code: currencyCode)))
                                    .font(VTypography.bodyBold)
                                    .monospacedDigit()
                                    .accessibilityIdentifier("outlook-annual-saving")
                            }
                            Text(String(localized: "\(scenario.categoryName) has typically cost \(scenario.baselineMonthly.formatted(.currency(code: currencyCode))) a month over \(scenario.baselineMonths) months."))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider()
                            ForEach(WhatIfScenarioEngine.caveats, id: \.self) { caveat in
                                Text(caveat)
                                    .font(VTypography.caption2)
                                    .foregroundStyle(VColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}
