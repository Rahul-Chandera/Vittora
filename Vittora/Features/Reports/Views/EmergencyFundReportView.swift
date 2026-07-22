import SwiftUI
import VittoraCore

struct EmergencyFundReportView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: EmergencyFundViewModel?
    @State private var showAddRecurring = false

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm {
                    if vm.isLoading && vm.snapshot == nil {
                        ProgressView()
                            .padding(.top, VSpacing.xxxl)
                    } else if let snapshot = vm.snapshot {
                        coverageCard(snapshot)
                        figuresCard(snapshot)
                        if snapshot.shortfallToThreeMonths > 0 {
                            shortfallCard(snapshot)
                        }
                        accountSources(vm)
                        disclaimer
                    } else if vm.error == nil {
                        emptyState
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .safeAreaInset(edge: .bottom) {
            VColors.background
                .frame(height: 72)
                .allowsHitTesting(false)
        }
        .background(VColors.background)
        .navigationTitle(String(localized: "Emergency Fund"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard vm == nil else { return }
            let model = EmergencyFundViewModel(
                useCase: EmergencyFundUseCase(
                    recurringRuleRepository: dependencies.recurringRuleRepository,
                    categoryRepository: dependencies.categoryRepository,
                    transactionRepository: dependencies.transactionRepository,
                    accountRepository: dependencies.accountRepository,
                    savingsGoalRepository: dependencies.savingsGoalRepository
                ),
                selectionStore: UserDefaultsEmergencyFundAccountSelectionStore()
            )
            vm = model
            await model.load()
        }
        .refreshable {
            await vm?.load()
        }
        .sheet(isPresented: $showAddRecurring) {
            RecurringFormView(onDismiss: {
                showAddRecurring = false
                Task { await vm?.load() }
            })
        }
        .errorAlert(message: errorBinding)
    }

    private func coverageCard(_ snapshot: EmergencyFundSnapshot) -> some View {
        VCard {
            VStack(spacing: VSpacing.lg) {
                ZStack {
                    Circle()
                        .stroke(VColors.tertiaryBackground, lineWidth: 18)
                    Circle()
                        .trim(from: 0, to: arcProgress(snapshot.coverageMonths))
                        .stroke(
                            statusColor(snapshot.status),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .fill(VColors.textSecondary)
                        .frame(width: 9, height: 9)
                        .offset(y: 105)
                    Circle()
                        .fill(VColors.textSecondary)
                        .frame(width: 9, height: 9)
                        .offset(y: -105)

                    VStack(spacing: VSpacing.xxs) {
                        Text(snapshot.coverageMonths, format: .number.precision(.fractionLength(1)))
                            .font(VTypography.amountLarge)
                            .amountScaling()
                        Text(String(localized: "months covered"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(width: 210, height: 210)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Emergency fund coverage"))
                .accessibilityIdentifier("emergency-fund-coverage-summary")
                .accessibilityValue(
                    String(
                        localized: "\(snapshot.coverageMonths.formatted(.number.precision(.fractionLength(1)))) months, \(statusTitle(snapshot.status))"
                    )
                )

                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    targetLegendRow(String(localized: "3-month target"))
                    targetLegendRow(String(localized: "6-month target"))
                }
                .font(VTypography.bodyBold)
                .foregroundStyle(VColors.textPrimary)

                Text(statusTitle(snapshot.status))
                    .font(VTypography.title3)
                    .foregroundStyle(statusColor(snapshot.status))
            }
        }
    }

    private func figuresCard(_ snapshot: EmergencyFundSnapshot) -> some View {
        VCard {
            VStack(spacing: VSpacing.md) {
                figureRow(
                    title: String(localized: "Current fund"),
                    amount: snapshot.currentFund,
                    color: VColors.savings
                )
                Divider()
                figureRow(
                    title: String(localized: "Monthly essentials"),
                    amount: snapshot.essentialMonthly,
                    color: VColors.expense
                )
                Divider()
                HStack {
                    Text(String(localized: "Baseline"))
                        .foregroundStyle(VColors.textSecondary)
                    Spacer()
                    Text(baselineLabel(snapshot.baselineSource))
                        .multilineTextAlignment(.trailing)
                }
                .font(VTypography.caption1)
            }
        }
    }

    private func figureRow(title: String, amount: Decimal, color: Color) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(VColors.textSecondary)
            Spacer()
            Text(CurrencyFormatter.format(amount, currencyCode: currencyCode))
                .font(VTypography.amountMedium)
                .amountScaling()
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(CurrencyFormatter.format(amount, currencyCode: currencyCode))
    }

    private func shortfallCard(_ snapshot: EmergencyFundSnapshot) -> some View {
        VCard {
            HStack(spacing: VSpacing.md) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(VColors.warning)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: VSpacing.xxs) {
                    Text(String(localized: "To reach 3 months"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    Text(CurrencyFormatter.format(snapshot.shortfallToThreeMonths, currencyCode: currencyCode))
                        .font(VTypography.amountMedium)
                        .amountScaling()
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Shortfall to reach three months"))
        .accessibilityValue(
            CurrencyFormatter.format(snapshot.shortfallToThreeMonths, currencyCode: currencyCode)
        )
    }

    private func accountSources(_ vm: EmergencyFundViewModel) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            Text(String(localized: "Contributing Accounts"))
                .font(VTypography.calloutBold)
                .foregroundStyle(VColors.textPrimary)
            Text(String(localized: "Choose accounts whose full balance should count toward this fund."))
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VCard {
                VStack(spacing: 0) {
                    if vm.accounts.isEmpty {
                        Text(String(localized: "No eligible asset accounts"))
                            .foregroundStyle(VColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(vm.accounts) { account in
                            Button {
                                Task {
                                    await vm.setAccount(
                                        account.id,
                                        selected: !vm.selectedAccountIDs.contains(account.id)
                                    )
                                }
                            } label: {
                                HStack {
                                    Label(account.name, systemImage: account.icon)
                                    Spacer()
                                    Text(CurrencyFormatter.format(account.balance, currencyCode: currencyCode))
                                        .foregroundStyle(VColors.textPrimary)
                                    Image(systemName: vm.selectedAccountIDs.contains(account.id)
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(vm.selectedAccountIDs.contains(account.id)
                                                         ? VColors.primary : VColors.textTertiary)
                                }
                                .padding(.vertical, VSpacing.sm)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(account.name)
                            .accessibilityValue(
                                vm.selectedAccountIDs.contains(account.id)
                                ? String(
                                    localized: "\(CurrencyFormatter.format(account.balance, currencyCode: currencyCode)), selected"
                                )
                                : String(
                                    localized: "\(CurrencyFormatter.format(account.balance, currencyCode: currencyCode)), not selected"
                                )
                            )
                            if account.id != vm.accounts.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var disclaimer: some View {
        Label(
            String(localized: "Three to six months is a general guideline, not personalized financial advice."),
            systemImage: "info.circle"
        )
        .font(VTypography.caption1)
        .foregroundStyle(VColors.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func targetLegendRow(_ title: String) -> some View {
        HStack(spacing: VSpacing.sm) {
            Circle()
                .fill(VColors.textPrimary)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        VEmptyState(
            icon: "shield.lefthalf.filled",
            title: String(localized: "No Essentials Baseline Yet"),
            subtitle: String(localized: "Add recurring essential expenses or classify expense categories as Needs to calculate your coverage."),
            actionLabel: String(localized: "Add Recurring Expense"),
            action: { showAddRecurring = true }
        )
        .frame(maxWidth: .infinity)
        .padding(.top, VSpacing.xxxl)
    }

    private func arcProgress(_ coverage: Decimal) -> CGFloat {
        CGFloat(min(1, max(0, (coverage as NSDecimalNumber).doubleValue / 6)))
    }

    private func statusTitle(_ status: EmergencyFundStatus) -> String {
        switch status {
        case .buildUp: String(localized: "Build up your buffer")
        case .onTrack: String(localized: "On track")
        case .comfortable: String(localized: "Comfortable buffer")
        }
    }

    private func statusColor(_ status: EmergencyFundStatus) -> Color {
        switch status {
        case .buildUp: VColors.warning
        case .onTrack: VColors.savings
        case .comfortable: VColors.primary
        }
    }

    private func baselineLabel(_ source: EmergencyFundBaselineSource) -> String {
        switch source {
        case .recurringRules:
            String(localized: "Recurring essentials")
        case .spendingHistory(let monthCount):
            String(localized: "\(monthCount) month(s) of available history")
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
        EmergencyFundReportView()
    }
}
