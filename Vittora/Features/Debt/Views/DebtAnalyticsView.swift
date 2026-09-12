// ponytail: every amount is in the single app display currency because DebtEntry has no currency code.
import SwiftUI
import VittoraCore

struct DebtAnalyticsView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var vm: DebtAnalyticsViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm {
                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                            .padding(.top, VSpacing.xxxl)
                    } else if let analytics = vm.analytics, vm.hasData {
                        analyticsContent(analytics)
                    } else {
                        emptyState
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .accessibilityIdentifier("debt-analytics-screen")
        .background(VColors.groupedBackground)
        .navigationTitle(String(localized: "Debt Analytics"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard vm == nil else { return }
            vm = DebtAnalyticsViewModel(
                useCase: CalculateDebtAnalyticsUseCase(
                    fetchLedgerUseCase: FetchDebtLedgerUseCase(
                        debtRepository: dependencies.debtRepository,
                        payeeRepository: dependencies.payeeRepository
                    ),
                    fetchOverdueUseCase: FetchOverdueDebtsUseCase(
                        debtRepository: dependencies.debtRepository
                    ),
                    debtRepository: dependencies.debtRepository
                )
            )
            await vm?.load()
        }
        .refreshable {
            await vm?.load()
        }
        .errorAlert(message: debtAnalyticsErrorBinding)
    }

    // MARK: - Content

    @ViewBuilder
    private func analyticsContent(_ analytics: DebtAnalytics) -> some View {
        let overdue = analytics.overdue
        if overdue.count > 0 || overdue.dueWithin7DaysCount > 0 {
            overdueRiskCard(overdue)
        }
        if !analytics.aging.isEmpty {
            agingCard(analytics.aging)
        }
        if !analytics.exposures.isEmpty {
            exposureCard(analytics)
        }
        velocityCard(analytics)
    }

    // MARK: - Overdue Risk

    private func overdueRiskCard(_ overdue: DebtOverdueRisk) -> some View {
        let outstanding = CurrencyFormatter.format(overdue.totalRemaining, currencyCode: currencyCode)
        return VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Overdue Risk"))
                    .font(VTypography.calloutBold)
                    .foregroundStyle(VColors.textPrimary)

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: VSpacing.sm) {
                        Text(String(localized: "\(overdue.count) overdue debts"))
                            .font(VTypography.body)
                            .foregroundStyle(VColors.textPrimary)
                        Text(outstanding)
                            .font(VTypography.amountMedium)
                            .amountScaling()
                            .foregroundStyle(VColors.expense)
                        Text(String(localized: "Worst: \(overdue.maxDaysOverdue) days overdue"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                        Text(String(localized: "\(overdue.dueWithin7DaysCount) due in the next 7 days"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: VSpacing.xs) {
                            Text(String(localized: "\(overdue.count) overdue debts"))
                                .font(VTypography.body)
                                .foregroundStyle(VColors.textPrimary)
                            Text(String(localized: "Worst: \(overdue.maxDaysOverdue) days overdue"))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textSecondary)
                            Text(String(localized: "\(overdue.dueWithin7DaysCount) due in the next 7 days"))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textSecondary)
                        }
                        Spacer()
                        Text(outstanding)
                            .font(VTypography.amountMedium)
                            .amountScaling()
                            .foregroundStyle(VColors.expense)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Overdue Risk"))
        .accessibilityValue(
            String(
                localized: "\(overdue.count) overdue debts, \(outstanding) outstanding, worst \(overdue.maxDaysOverdue) days overdue, \(overdue.dueWithin7DaysCount) due in the next 7 days"
            )
        )
    }

    // MARK: - Aging

    private func agingCard(_ aging: [DebtAgingBucket]) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "How Long Debts Have Been Open"))
                    .font(VTypography.calloutBold)
                    .foregroundStyle(VColors.textPrimary)

                VStack(spacing: 0) {
                    ForEach(Array(aging.enumerated()), id: \.element.id) { index, bucket in
                        agingRow(bucket)
                        if index < aging.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func agingRow(_ bucket: DebtAgingBucket) -> some View {
        let owedToMe = CurrencyFormatter.format(bucket.owedToMe, currencyCode: currencyCode)
        let iOwe = CurrencyFormatter.format(bucket.iOwe, currencyCode: currencyCode)
        let name = bucket.bucket.displayName

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    Text(name)
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                    if bucket.owedToMe != 0 {
                        Text(owedToMe)
                            .font(VTypography.body)
                            .amountScaling()
                            .foregroundStyle(VColors.income)
                    }
                    if bucket.iOwe != 0 {
                        Text(iOwe)
                            .font(VTypography.body)
                            .amountScaling()
                            .foregroundStyle(VColors.expense)
                    }
                    Text(String(localized: "\(bucket.count) debts"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, VSpacing.sm)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(name)
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if bucket.owedToMe != 0 {
                            Text(owedToMe)
                                .font(VTypography.body)
                                .amountScaling()
                                .foregroundStyle(VColors.income)
                        }
                        if bucket.iOwe != 0 {
                            Text(iOwe)
                                .font(VTypography.body)
                                .amountScaling()
                                .foregroundStyle(VColors.expense)
                        }
                        Text(String(localized: "\(bucket.count) debts"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                    }
                }
                .padding(.vertical, VSpacing.sm)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Aging bucket"))
        .accessibilityValue(agingAccessibilityValue(bucket, name: name, owedToMe: owedToMe, iOwe: iOwe))
    }

    private func agingAccessibilityValue(
        _ bucket: DebtAgingBucket,
        name: String,
        owedToMe: String,
        iOwe: String
    ) -> String {
        var parts: [String] = [name, String(localized: "\(bucket.count) debts")]
        if bucket.owedToMe != 0 {
            parts.append(String(localized: "\(owedToMe) owed to you"))
        }
        if bucket.iOwe != 0 {
            parts.append(String(localized: "\(iOwe) you owe"))
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Exposure

    private func exposureCard(_ analytics: DebtAnalytics) -> some View {
        let exposures = analytics.exposures
        let shown = Array(exposures.prefix(10))

        return VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Exposure by Person"))
                    .font(VTypography.calloutBold)
                    .foregroundStyle(VColors.textPrimary)

                if let share = analytics.concentrationShare,
                   let name = analytics.concentrationPayeeName {
                    Text(
                        String(
                            localized: "\(name) accounts for \(share.formatted(.percent.precision(.fractionLength(0)))) of what you are owed"
                        )
                    )
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, exposure in
                        exposureRow(exposure)
                        if index < shown.count - 1 {
                            Divider()
                        }
                    }
                }

                if exposures.count > 10 {
                    Text(String(localized: "Showing top 10 of \(exposures.count)"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textTertiary)
                }
            }
        }
    }

    private func exposureRow(_ exposure: CounterpartyExposure) -> some View {
        let netFormatted = CurrencyFormatter.format(exposure.net, currencyCode: currencyCode)
        let netColor = exposure.net >= 0 ? VColors.income : VColors.expense

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    Text(exposure.payeeName)
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                    Text(netFormatted)
                        .font(VTypography.body)
                        .amountScaling()
                        .foregroundStyle(netColor)
                    Text(String(localized: "Oldest: \(exposure.oldestOutstandingDays) days"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    if let velocity = exposure.settlementVelocity {
                        Text(String(localized: "Usually settles in \(velocity.medianDays) days"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                    }
                    if exposure.overdueCount > 0 {
                        Text(String(localized: "\(exposure.overdueCount) overdue"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.expense)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, VSpacing.sm)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exposure.payeeName)
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.textPrimary)
                        HStack(spacing: VSpacing.md) {
                            Text(String(localized: "Oldest: \(exposure.oldestOutstandingDays) days"))
                            if let velocity = exposure.settlementVelocity {
                                Text(String(localized: "Usually settles in \(velocity.medianDays) days"))
                                    .font(VTypography.caption1)
                                    .foregroundStyle(VColors.textSecondary)
                            }
                            if exposure.overdueCount > 0 {
                                Text(String(localized: "\(exposure.overdueCount) overdue"))
                                    .foregroundStyle(VColors.expense)
                            }
                        }
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    }
                    Spacer()
                    Text(netFormatted)
                        .font(VTypography.bodyBold)
                        .amountScaling()
                        .foregroundStyle(netColor)
                }
                .padding(.vertical, VSpacing.sm)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Counterparty exposure"))
        .accessibilityValue(exposureAccessibilityValue(exposure, netFormatted: netFormatted))
    }

    private func exposureAccessibilityValue(
        _ exposure: CounterpartyExposure,
        netFormatted: String
    ) -> String {
        var value = String(
            localized: "\(exposure.payeeName), net \(netFormatted), oldest \(exposure.oldestOutstandingDays) days"
        )
        if exposure.overdueCount > 0 {
            value += String(localized: ", \(exposure.overdueCount) overdue")
        }
        if let velocity = exposure.settlementVelocity {
            value += String(localized: ", usually settles in \(velocity.medianDays) days")
        }
        return value
    }

    // MARK: - Velocity

    private func velocityCard(_ analytics: DebtAnalytics) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "How Fast Debts Get Settled"))
                    .font(VTypography.calloutBold)
                    .foregroundStyle(VColors.textPrimary)

                if let velocity = analytics.velocity {
                    Text(String(localized: "Typically settled in \(velocity.medianDays) days"))
                        .font(VTypography.body)
                        .foregroundStyle(VColors.textPrimary)
                    Text(String(localized: "Median of \(velocity.sampleSize) settled debts"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textTertiary)
                } else {
                    Text(
                        String(
                            localized: "Not enough settled debts yet — \(analytics.settledSampleSize) of \(DebtAnalytics.minimumVelocitySample) needed"
                        )
                    )
                    .font(VTypography.body)
                    .foregroundStyle(VColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "How Fast Debts Get Settled"))
        .accessibilityValue(velocityAccessibilityValue(analytics))
    }

    private func velocityAccessibilityValue(_ analytics: DebtAnalytics) -> String {
        if let velocity = analytics.velocity {
            return String(
                localized: "Typically settled in \(velocity.medianDays) days, median of \(velocity.sampleSize) settled debts"
            )
        }
        return String(
            localized: "Not enough settled debts yet — \(analytics.settledSampleSize) of \(DebtAnalytics.minimumVelocitySample) needed"
        )
    }

    // MARK: - Empty

    private var emptyState: some View {
        ContentUnavailableView {
            Label(String(localized: "Nothing to analyse yet"), systemImage: "chart.bar.xaxis")
        } description: {
            Text(String(localized: "Add debts you lent or borrowed and their analytics will appear here"))
        }
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical, alignment: .center)
    }

    // MARK: - Error binding

    private var debtAnalyticsErrorBinding: Binding<String?> {
        Binding(
            get: { vm?.error },
            set: { newValue in
                vm?.error = newValue
            }
        )
    }
}
