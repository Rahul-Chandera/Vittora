import SwiftUI
import VittoraCore

struct SubscriptionAuditReportView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: SubscriptionAuditViewModel?
    @State private var showAddRecurring = false

    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.sectionSpacing) {
                if let vm {
                    if vm.isLoading {
                        ProgressView().tint(VColors.primary)
                            .padding(.top, VSpacing.xxxl)
                    } else if vm.isEmpty {
                        emptyState
                    } else if let report = vm.report {
                        insightLine(report)
                        totalsHeader(report)
                        rulesList(report)
                    }
                }
            }
            .padding(VSpacing.screenPadding)
        }
        .background(VColors.groupedBackground)
        .navigationTitle(String(localized: "Subscription Audit"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            guard vm == nil else { return }
            vm = SubscriptionAuditViewModel(
                useCase: SubscriptionAuditUseCase(
                    recurringRuleRepository: dependencies.recurringRuleRepository,
                    categoryRepository: dependencies.categoryRepository,
                    transactionRepository: dependencies.transactionRepository
                )
            )
            await vm?.load()
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
        .errorAlert(message: subscriptionAuditErrorBinding)
    }

    // MARK: - Insight

    private func insightLine(_ report: SubscriptionAuditReport) -> some View {
        let monthly = CurrencyFormatter.format(report.monthlyTotal, currencyCode: currencyCode)
        let annual = CurrencyFormatter.format(report.annualTotal, currencyCode: currencyCode)
        let text = String(
            localized: "\(report.ruleCount) recurring charges · \(monthly)/month · \(annual)/year"
        )
        return Text(text)
            .font(VTypography.callout)
            .foregroundStyle(VColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(text)
    }

    // MARK: - Totals

    private func totalsHeader(_ report: SubscriptionAuditReport) -> some View {
        VCard {
            HStack(spacing: VSpacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Monthly Total"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    Text(CurrencyFormatter.format(report.monthlyTotal, currencyCode: currencyCode))
                        .font(VTypography.amountMedium)
                        .amountScaling()
                        .foregroundStyle(VColors.expense)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(localized: "Annual Total"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    Text(CurrencyFormatter.format(report.annualTotal, currencyCode: currencyCode))
                        .font(VTypography.amountMedium)
                        .amountScaling()
                        .foregroundStyle(VColors.expense)
                }
            }
        }
    }

    // MARK: - Rows

    private func rulesList(_ report: SubscriptionAuditReport) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Active Recurring Expenses"))
                .font(VTypography.calloutBold)
                .foregroundStyle(VColors.textPrimary)

            VStack(spacing: 0) {
                ForEach(report.rows) { row in
                    rowView(row)
                    if row.id != report.rows.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, VSpacing.cardPadding)
            .padding(.vertical, VSpacing.xs)
            .background(VColors.secondaryGroupedBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
    }

    private func rowView(_ row: SubscriptionAuditRow) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                        .adaptiveLineLimit(1)
                    Text(row.categoryName)
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormatter.format(row.monthlyCost, currencyCode: currencyCode))
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.expense)
                    Text(String(localized: "per month"))
                        .font(VTypography.caption2)
                        .foregroundStyle(VColors.textTertiary)
                }
            }

            HStack(spacing: VSpacing.md) {
                Label(frequencyLabel(row.frequency), systemImage: "arrow.triangle.2.circlepath")
                Text(CurrencyFormatter.format(row.amount, currencyCode: currencyCode))
                Spacer()
                Text(lastRanLabel(row.lastRan))
            }
            .font(VTypography.caption2)
            .foregroundStyle(VColors.textSecondary)
        }
        .padding(.vertical, VSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: row))
    }

    // MARK: - Empty

    private var emptyState: some View {
        VEmptyState(
            icon: "arrow.triangle.2.circlepath",
            title: String(localized: "No Recurring Expenses"),
            subtitle: String(localized: "Create a recurring expense to see what you pay each month."),
            actionLabel: String(localized: "Add Recurring Expense"),
            action: { showAddRecurring = true }
        )
        .frame(maxWidth: .infinity)
        .padding(.top, VSpacing.xxxl)
    }

    // MARK: - Helpers

    private func frequencyLabel(_ frequency: RecurrenceFrequency) -> String {
        switch frequency {
        case .daily:
            return String(localized: "Daily")
        case .weekly:
            return String(localized: "Weekly")
        case .biweekly:
            return String(localized: "Bi-weekly")
        case .monthly:
            return String(localized: "Monthly")
        case .quarterly:
            return String(localized: "Quarterly")
        case .yearly:
            return String(localized: "Yearly")
        case .custom(let days):
            return String(localized: "Every \(days) days")
        }
    }

    private func lastRanLabel(_ date: Date?) -> String {
        guard let date else {
            return String(localized: "Not yet run")
        }
        let formatted = date.formatted(date: .abbreviated, time: .omitted)
        return String(localized: "Last ran \(formatted)")
    }

    private func accessibilityLabel(for row: SubscriptionAuditRow) -> String {
        let monthly = CurrencyFormatter.format(row.monthlyCost, currencyCode: currencyCode)
        let amount = CurrencyFormatter.format(row.amount, currencyCode: currencyCode)
        return String(
            localized: "\(row.name), \(row.categoryName), \(frequencyLabel(row.frequency)), \(amount), \(monthly) per month, \(lastRanLabel(row.lastRan))"
        )
    }

    private var subscriptionAuditErrorBinding: Binding<String?> {
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
        SubscriptionAuditReportView()
    }
}
