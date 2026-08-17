import SwiftUI
import Charts
import VittoraCore

@Observable
@MainActor
private final class NetWorthViewModel {
    var accounts: [AccountEntity] = []
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

    init(repository: any AccountRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            accounts = try await repository.fetchAll()
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
            vm = NetWorthViewModel(repository: dependencies.accountRepository)
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
