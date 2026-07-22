import SwiftUI
import VittoraCore

struct FiftyThirtyTwentyReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: FiftyThirtyTwentyViewModel?

    private let colors: [SpendingBucket: Color] = [
        .needs: VColors.primary,
        .wants: VColors.warning,
        .savings: VColors.savings,
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                monthPicker
                disclaimer
                if let vm {
                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                            .padding(.top, VSpacing.xxxl)
                    } else if let snapshot = vm.snapshot {
                        if let comparison = snapshot.comparison {
                            stackedBar(comparison)
                            rows(comparison)
                            verdict(comparison)
                        } else {
                            zeroIncomePrompt
                        }
                        uncategorizedNote
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.background)
        .navigationTitle(String(localized: "50/30/20"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard vm == nil else { return }
            vm = FiftyThirtyTwentyViewModel(
                useCase: FiftyThirtyTwentyReportUseCase(
                    transactionRepository: dependencies.transactionRepository,
                    categoryRepository: dependencies.categoryRepository,
                    debtRepository: dependencies.debtRepository
                )
            )
        }
        .task(id: vm?.selectedMonth) {
            guard vm != nil else { return }
            await vm?.load()
        }
        .task(id: appState.refreshVersion(for: .categories)) {
            guard vm != nil, appState.refreshVersion(for: .categories) > 0 else { return }
            await vm?.load()
        }
        .task(id: appState.refreshVersion(for: .transactions)) {
            guard vm != nil, appState.refreshVersion(for: .transactions) > 0 else { return }
            await vm?.load()
        }
        .task(id: appState.refreshVersion(for: .debt)) {
            guard vm != nil, appState.refreshVersion(for: .debt) > 0 else { return }
            await vm?.load()
        }
        .task(id: appState.refreshVersion(for: .savings)) {
            guard vm != nil, appState.refreshVersion(for: .savings) > 0 else { return }
            await vm?.load()
        }
        .refreshable { await vm?.load() }
        .errorAlert(message: errorBinding)
    }

    private var monthPicker: some View {
        VCard {
            HStack {
                Text(String(localized: "Month"))
                    .font(VTypography.bodyBold)
                Spacer()
                if let vm {
                    DatePicker(
                        String(localized: "Month"),
                        selection: Bindable(vm).selectedMonth,
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                }
            }
        }
    }

    private var disclaimer: some View {
        VCard {
            Label(
                String(localized: "This is a general guideline, not financial advice."),
                systemImage: "info.circle"
            )
            .font(VTypography.caption1)
            .foregroundStyle(VColors.textSecondary)
            .adaptiveLineLimit(3)
            .adaptiveMinimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("fifty-thirty-twenty-disclaimer")
        }
    }

    private func stackedBar(_ result: FiftyThirtyTwentyResult) -> some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(result.rows) { row in
                    let fraction = result.amounts.totalSpending > 0
                        ? row.amount / result.amounts.totalSpending
                        : 0
                    Rectangle()
                        .fill(colors[row.bucket] ?? VColors.textTertiary)
                        .frame(width: proxy.size.width * decimalDouble(fraction))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Needs, wants, and savings distribution"))
        .accessibilityIdentifier("fifty-thirty-twenty-stacked-bar")
    }

    private func rows(_ result: FiftyThirtyTwentyResult) -> some View {
        VStack(spacing: 0) {
            ForEach(result.rows) { row in
                HStack(alignment: .top, spacing: VSpacing.md) {
                    Circle()
                        .fill(colors[row.bucket] ?? VColors.textTertiary)
                        .frame(width: 10, height: 10)
                        .padding(.top, 6)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.bucket.displayName)
                            .font(VTypography.bodyBold)
                            .adaptiveLineLimit(1)
                            .adaptiveMinimumScaleFactor(0.8)
                        Text(
                            String(
                                localized: "\(percent(row.actualPercent)) actual · \(percent(row.targetPercent)) target"
                            )
                        )
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                        .adaptiveLineLimit(2)
                        .adaptiveMinimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(CurrencyFormatter.format(row.amount, currencyCode: currencyCode))
                            .font(VTypography.bodyBold)
                            .amountScaling()
                        Text(varianceLabel(row.variancePoints))
                            .font(VTypography.caption1)
                            .foregroundStyle(row.variancePoints > 0 ? VColors.expense : VColors.income)
                            .adaptiveLineLimit(1)
                            .adaptiveMinimumScaleFactor(0.75)
                            .multilineTextAlignment(.trailing)
                    }
                    .layoutPriority(1)
                }
                .padding(VSpacing.cardPadding)
                if row.id != result.rows.last?.id { Divider() }
            }
        }
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    private func verdict(_ result: FiftyThirtyTwentyResult) -> some View {
        let row = result.rows.max { abs($0.variancePoints) < abs($1.variancePoints) }
        return VCard {
            Text(row.map(verdictText) ?? "")
                .font(VTypography.calloutBold)
                .foregroundStyle(VColors.textPrimary)
                .adaptiveLineLimit(4)
                .adaptiveMinimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var zeroIncomePrompt: some View {
        VCard {
            Label(
                String(localized: "Add income to see this comparison"),
                systemImage: "plus.circle"
            )
            .font(VTypography.bodyBold)
            .adaptiveLineLimit(3)
            .adaptiveMinimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("fifty-thirty-twenty-zero-income")
        }
    }

    private var uncategorizedNote: some View {
        Text(String(localized: "Uncategorized expenses count as wants."))
            .font(VTypography.caption1)
            .foregroundStyle(VColors.textSecondary)
            .adaptiveLineLimit(3)
            .adaptiveMinimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func verdictText(_ row: FiftyThirtyTwentyRow) -> String {
        let direction = row.variancePoints >= 0
            ? String(localized: "over")
            : String(localized: "under")
        return String(
            localized: "\(row.bucket.displayName) are \(percent(abs(row.variancePoints))) \(direction) the guideline"
        )
    }

    private func varianceLabel(_ variance: Decimal) -> String {
        let direction = variance >= 0 ? String(localized: "over") : String(localized: "under")
        return String(localized: "\(percent(abs(variance))) \(direction)")
    }

    private func percent(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(1))) + "%"
    }

    private func decimalDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    private var errorBinding: Binding<String?> {
        Binding(get: { vm?.error }, set: { vm?.error = $0 })
    }
}
