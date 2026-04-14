import SwiftUI
import Charts

@Observable
@MainActor
private final class NetWorthViewModel {
    var accounts: [AccountEntity] = []
    var isLoading = false
    var error: String?

    var assets: [AccountEntity] { accounts.filter { $0.type.isAsset && !$0.isArchived } }
    var liabilities: [AccountEntity] { accounts.filter { !$0.type.isAsset && !$0.isArchived } }
    var totalAssets: Decimal { assets.reduce(Decimal(0)) { $0 + $1.balance } }
    var totalLiabilities: Decimal { liabilities.reduce(Decimal(0)) { $0 + $1.balance } }
    var netWorth: Decimal { totalAssets - totalLiabilities }

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
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct NetWorthReportView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: NetWorthViewModel?

    private var currencyCode: String {
        UserDefaults.standard.string(forKey: "vittora.currencyCode") ?? "USD"
    }

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
                                total: vm.totalAssets,
                                accentColor: VColors.income
                            )
                        }
                        if !vm.liabilities.isEmpty {
                            accountSection(
                                title: String(localized: "Liabilities"),
                                accounts: vm.liabilities,
                                total: vm.totalLiabilities,
                                accentColor: VColors.expense
                            )
                        }
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.background)
        .navigationTitle(String(localized: "Net Worth"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard vm == nil, let repo = dependencies.accountRepository else { return }
            vm = NetWorthViewModel(repository: repo)
            await vm?.load()
        }
        .refreshable {
            await vm?.load()
        }
    }

    // MARK: - Net Worth Summary

    private func netWorthSummary(_ vm: NetWorthViewModel) -> some View {
        let nw = vm.netWorth
        return VCard {
            VStack(spacing: VSpacing.lg) {
                VStack(spacing: 4) {
                    Text(String(localized: "Net Worth"))
                        .font(VTypography.subheadline)
                        .foregroundStyle(VColors.textSecondary)
                    Text(nw >= 0
                         ? nw.formatted(.currency(code: currencyCode))
                         : "-\(abs(nw).formatted(.currency(code: currencyCode)))")
                        .font(VTypography.amountLarge)
                        .foregroundStyle(nw >= 0 ? VColors.income : VColors.expense)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Total Assets"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                        Text(vm.totalAssets.formatted(.currency(code: currencyCode)))
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.income)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(localized: "Total Liabilities"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                        Text(vm.totalLiabilities.formatted(.currency(code: currencyCode)))
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.expense)
                    }
                }

                // Composition bar
                if vm.totalAssets > 0 {
                    compositionBar(vm)
                }
            }
        }
    }

    private func compositionBar(_ vm: NetWorthViewModel) -> some View {
        let total = vm.totalAssets + vm.totalLiabilities
        let assetFraction = total > 0
            ? Double(truncating: (vm.totalAssets / total) as NSDecimalNumber)
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
        total: Decimal,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            HStack {
                Text(title)
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)
                Spacer()
                Text(total.formatted(.currency(code: currencyCode)))
                    .font(VTypography.caption1.bold())
                    .foregroundStyle(accentColor)
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
                            Text(account.type.rawValue.capitalized)
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
            .background(VColors.secondaryBackground)
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
}

#Preview {
    NavigationStack {
        NetWorthReportView()
    }
}
