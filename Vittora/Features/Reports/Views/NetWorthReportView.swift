import SwiftUI
import Charts
import VittoraCore

@Observable
@MainActor
private final class NetWorthViewModel {
    var accounts: [AccountEntity] = []
    var history: NetWorthHistory?
    var isLoading = false
    var error: String?

    var assets: [AccountEntity] { accounts.filter { $0.type.isAsset && !$0.isArchived } }
    var liabilities: [AccountEntity] { accounts.filter { !$0.type.isAsset && !$0.isArchived } }
    /// Per currency. Summing balances across currencies and labelling the
    /// result with the display currency relabels rather than converts — see
    /// NetWorthSummary.
    var summary: NetWorthSummary {
        NetWorthSummary.build(from: accounts.filter { !$0.isArchived })
    }

    private let repository: any AccountRepository
    private let historyUseCase: CalculateNetWorthHistoryUseCase

    init(repository: any AccountRepository, historyUseCase: CalculateNetWorthHistoryUseCase) {
        self.repository = repository
        self.historyUseCase = historyUseCase
    }

    /// A currency's series, oldest first.
    func trendPoints(for currencyCode: String) -> [TrendDataPoint] {
        (history?.points ?? []).compactMap { point in
            point.netWorth(inCurrency: currencyCode).map {
                TrendDataPoint(date: point.date, amount: $0)
            }
        }
    }

    /// Green when the period ended higher than it started, red when lower. Stated from the
    /// data rather than assumed: net worth going down is a normal month for anyone paying
    /// off a loan, and colouring it red regardless would editorialise.
    func trendColor(for currencyCode: String) -> Color {
        let points = trendPoints(for: currencyCode)
        guard let first = points.first?.amount, let last = points.last?.amount else {
            return VColors.primary
        }
        return last >= first ? VColors.income : VColors.expense
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            accounts = try await repository.fetchAll()
            // Failure here must not take the whole report down: the point-in-time figure
            // and the account lists below are still useful without a chart.
            history = try? await historyUseCase.execute()
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load net worth right now.")
            )
        }
        isLoading = false
    }
}

struct NetWorthReportView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: NetWorthViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm {
                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                            .padding(.top, VSpacing.xxxl)
                    } else if vm.accounts.isEmpty {
                        emptyState
                    } else {
                        netWorthSummary(vm)
                        historySection(vm)
                        if !vm.assets.isEmpty {
                            accountSection(
                                title: String(localized: "Assets"),
                                accounts: vm.assets,
                                accentColor: VColors.income
                            )
                        }
                        if !vm.liabilities.isEmpty {
                            accountSection(
                                title: String(localized: "Liabilities"),
                                accounts: vm.liabilities,
                                accentColor: VColors.expense
                            )
                        }
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.groupedBackground)
        .navigationTitle(String(localized: "Net Worth"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard vm == nil else { return }
            vm = NetWorthViewModel(
                repository: dependencies.accountRepository,
                historyUseCase: CalculateNetWorthHistoryUseCase(
                    accountRepository: dependencies.accountRepository,
                    transactionRepository: dependencies.transactionRepository
                )
            )
            await vm?.load()
        }
        .refreshable {
            await vm?.load()
        }
        .errorAlert(message: netWorthErrorBinding)
    }

    // MARK: - Net Worth Summary

    @ViewBuilder
    private func currencySummaryBlock(
        _ totals: NetWorthSummary.CurrencyTotals,
        showsCode: Bool
    ) -> some View {
        let net = totals.netWorth
        VStack(spacing: VSpacing.lg) {
            VStack(spacing: 4) {
                Text(showsCode
                     ? String(localized: "Net Worth (\(totals.currencyCode))")
                     : String(localized: "Net Worth"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)
                Text(net >= 0
                     ? net.formatted(.currency(code: totals.currencyCode))
                     : "-\(abs(net).formatted(.currency(code: totals.currencyCode)))")
                    .font(VTypography.amountLarge)
                    .amountScaling()
                    .foregroundStyle(net >= 0 ? VColors.income : VColors.expense)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Total Assets"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    Text(totals.assets.formatted(.currency(code: totals.currencyCode)))
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.income)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(localized: "Total Liabilities"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    Text(totals.liabilities.formatted(.currency(code: totals.currencyCode)))
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.expense)
                }
            }
        }
    }

    private func netWorthSummary(_ vm: NetWorthViewModel) -> some View {
        let entries = vm.summary.byCurrency.isEmpty
            ? [NetWorthSummary.CurrencyTotals(currencyCode: currencyCode, assets: 0, liabilities: 0)]
            : vm.summary.byCurrency

        return VCard {
            VStack(spacing: VSpacing.lg) {
                // One block per currency: an INR balance shown under a dollar
                // sign was overstating net worth by the whole exchange rate.
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, totals in
                    if index > 0 { Divider() }
                    currencySummaryBlock(totals, showsCode: vm.summary.isMultiCurrency)
                }

                // Composition bar reads the dominant currency only; mixing
                // currencies into one bar would be the same category error.
                if let leading = entries.first, leading.assets > 0 {
                    compositionBar(vm)
                }
            }
        }
    }

    private func compositionBar(_ vm: NetWorthViewModel) -> some View {
        // Dominant currency only. Adding an INR asset to a USD liability to get
        // a ratio is the same category error as summing them for a total.
        let leading = vm.summary.byCurrency.first
        let assets = leading?.assets ?? 0
        let liabilities = leading?.liabilities ?? 0
        let total = assets + liabilities
        let assetFraction = total > 0
            ? Double(truncating: (assets / total) as NSDecimalNumber)
            : 1.0

        return GeometryReader { geo in
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(VColors.income)
                    .frame(width: max(4, geo.size.width * CGFloat(assetFraction) - 1))
                RoundedRectangle(cornerRadius: 4)
                    .fill(VColors.expense)
            }
            .frame(height: 10)
        }
        .frame(height: 10)
    }

    // MARK: - Account Section

    /// One chart per currency (M1.7.7).
    ///
    /// Never one combined line: balances are not summed across currencies anywhere in this
    /// feature, because doing so relabels rather than converts — see NetWorthSummary. A
    /// single "net worth over time" line would reintroduce exactly the bug that decision
    /// was made to fix.
    @ViewBuilder
    private func historySection(_ vm: NetWorthViewModel) -> some View {
        if let history = vm.history, !history.isEmpty {
            VCard {
                VStack(alignment: .leading, spacing: VSpacing.md) {
                    Text(String(localized: "Over Time"))
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)

                    ForEach(history.currencyCodes, id: \.self) { code in
                        let points = vm.trendPoints(for: code)
                        if points.count > 1 {
                            VStack(alignment: .leading, spacing: VSpacing.xs) {
                                if history.currencyCodes.count > 1 {
                                    Text(code)
                                        .font(VTypography.caption1)
                                        .foregroundStyle(VColors.textSecondary)
                                }
                                TrendAreaChart(
                                    dataPoints: points,
                                    color: vm.trendColor(for: code),
                                    currencyCode: code
                                )
                                .frame(height: 180)
                                changeLabel(points: points, currencyCode: code)
                            }
                        }
                    }

                    if !history.nonDerivableAccountNames.isEmpty {
                        // Naming them beats a silently shorter chart: these accounts have a
                        // transfer with no recorded direction, so their past balance cannot
                        // be reconstructed and a line for them would be a guess.
                        Text(String(localized: "Not charted: \(history.nonDerivableAccountNames.formatted(.list(type: .and))). An older transfer on these accounts has no direction recorded, so their past balance can't be worked out."))
                            .font(VTypography.caption2)
                            .foregroundStyle(VColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityIdentifier("net-worth-history-card")
        }
    }

    @ViewBuilder
    private func changeLabel(points: [TrendDataPoint], currencyCode: String) -> some View {
        if let first = points.first?.amount, let last = points.last?.amount {
            let change = last - first
            Text(
                change == 0
                    ? String(localized: "No change over this period")
                    : String(localized: "\(change.formatted(.currency(code: currencyCode))) over this period")
            )
            .font(VTypography.caption1)
            .foregroundStyle(change >= 0 ? VColors.income : VColors.expense)
            .accessibilityIdentifier("net-worth-history-change-\(currencyCode)")
        }
    }

    private func accountSection(
        title: String,
        accounts: [AccountEntity],
        accentColor: Color
    ) -> some View {
        // Subtotal per currency rather than one figure: these accounts can be
        // in different currencies and there is nothing to convert them with.
        var byCurrency: [String: Decimal] = [:]
        for account in accounts {
            byCurrency[account.currencyCode, default: 0] += account.balance
        }
        let subtotals = byCurrency.keys.sorted().map { code in
            (code: code, amount: byCurrency[code] ?? 0)
        }

        return VStack(alignment: .leading, spacing: VSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(subtotals, id: \.code) { subtotal in
                        Text(subtotal.amount.formatted(.currency(code: subtotal.code)))
                            .font(VTypography.caption1.bold())
                            .foregroundStyle(accentColor)
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(accounts.sorted { $0.balance > $1.balance }) { account in
                    HStack(spacing: VSpacing.md) {
                        Image(systemName: account.icon)
                            .font(.title3)
                            .foregroundStyle(accentColor)
                            .frame(width: 32)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                                .font(VTypography.body)
                                .foregroundStyle(VColors.textPrimary)
                            Text(account.type.displayName)
                                .font(VTypography.caption2)
                                .foregroundStyle(VColors.textTertiary)
                        }

                        Spacer()

                        Text(account.balance.formatted(.currency(code: account.currencyCode)))
                            .font(VTypography.bodyBold)
                            .foregroundStyle(accentColor)
                    }
                    .padding(.vertical, VSpacing.sm)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(account.name), \(account.balance.formatted(.currency(code: account.currencyCode)))")

                    Divider()
                }
            }
            .padding(.horizontal, VSpacing.cardPadding)
            .padding(.vertical, VSpacing.xs)
            .background(VColors.secondaryGroupedBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: VSpacing.lg) {
            Image(systemName: "scalemass.fill")
                .font(.system(size: 48))
                .foregroundStyle(VColors.textTertiary)
            Text(String(localized: "No accounts yet"))
                .font(VTypography.bodyBold)
                .foregroundStyle(VColors.textPrimary)
            Text(String(localized: "Add accounts to track your net worth"))
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(VSpacing.xxxl)
    }

    private var netWorthErrorBinding: Binding<String?> {
        Binding(
            get: { vm?.error },
            set: { newValue in
                vm?.error = newValue
            }
        )
    }
}

#Preview {
    NavigationStack {
        NetWorthReportView()
    }
}
