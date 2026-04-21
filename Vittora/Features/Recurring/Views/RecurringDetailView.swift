import SwiftUI

struct RecurringDetailView: View {
    @Environment(\.dependencies) var dependencies
    @Environment(\.currencyCode) private var currencyCode
    let ruleID: UUID
    @State private var rule: RecurringRuleEntity?
    @State private var category: CategoryEntity?
    @State private var account: AccountEntity?
    @State private var payee: PayeeEntity?
    @State private var recentTransactions: [TransactionEntity] = []
    @State private var isLoading = true
    @State private var showEditSheet = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            VColors.background.ignoresSafeArea()

            if let rule = rule {
                ScrollView {
                    VStack(alignment: .leading, spacing: VSpacing.lg) {
                        // Header Card
                        VStack(alignment: .leading, spacing: VSpacing.md) {
                            HStack(spacing: VSpacing.md) {
                                // Icon
                                ZStack {
                                    Circle()
                                        .fill(categoryColor)
                                        .opacity(0.15)

                                    Image(systemName: category?.icon ?? "tag.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(categoryColor)
                                }
                                .frame(width: 52, height: 52)

                                VStack(alignment: .leading, spacing: VSpacing.xs) {
                                    Text(category?.name ?? String(localized: "Uncategorized"))
                                        .font(VTypography.title2)
                                        .foregroundColor(VColors.textPrimary)

                                    Text(frequencyLabel(rule.frequency))
                                        .font(VTypography.callout)
                                        .foregroundColor(VColors.textSecondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: VSpacing.xs) {
                                    Text(rule.templateAmount.formatted(currencyCode: currencyCode))
                                        .font(VTypography.amountMedium)
                                        .foregroundColor(VColors.expense)

                                    Text(String(localized: "per transaction"))
                                        .font(VTypography.caption2)
                                        .foregroundColor(VColors.textSecondary)
                                }
                            }

                            Divider()

                            // Status and dates
                            HStack {
                                Label(
                                    rule.isActive ? String(localized: "Active") : String(localized: "Paused"),
                                    systemImage: rule.isActive ? "checkmark.circle.fill" : "pause.circle.fill"
                                )
                                .font(VTypography.callout)
                                .foregroundColor(rule.isActive ? .green : .orange)

                                Spacer()

                                Text(String(localized: "Next: \(rule.nextDate.formatted(date: .abbreviated, time: .omitted))"))
                                    .font(VTypography.callout)
                                    .foregroundColor(VColors.textSecondary)
                            }

                            if let endDate = rule.endDate {
                                Divider()

                                HStack {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(VColors.warning)

                                    Text(String(localized: "Ends: \(endDate.formatted(date: .abbreviated, time: .omitted))"))
                                        .font(VTypography.callout)
                                        .foregroundColor(VColors.textSecondary)

                                    Spacer()
                                }
                            }
                        }
                        .padding(VSpacing.lg)
                        .background(VColors.secondaryBackground)
                        .cornerRadius(VSpacing.cornerRadiusMD)

                        // Pause/Resume Button
                        HStack(spacing: VSpacing.md) {
                            Button(action: togglePause) {
                                Label(
                                    rule.isActive ? String(localized: "Pause") : String(localized: "Resume"),
                                    systemImage: rule.isActive ? "pause.circle.fill" : "play.circle.fill"
                                )
                                .font(VTypography.calloutBold)
                                .frame(maxWidth: .infinity)
                                .padding(VSpacing.md)
                                .background(VColors.warning.opacity(0.1))
                                .foregroundColor(VColors.warning)
                                .cornerRadius(VSpacing.cornerRadiusMD)
                            }

                            Button(action: { showEditSheet = true }) {
                                Label("Edit", systemImage: "pencil")
                                    .font(VTypography.calloutBold)
                                    .frame(maxWidth: .infinity)
                                    .padding(VSpacing.md)
                                    .background(VColors.primary.opacity(0.1))
                                    .foregroundColor(VColors.primary)
                                    .cornerRadius(VSpacing.cornerRadiusMD)
                            }
                        }

                        // Details Section
                        VStack(alignment: .leading, spacing: VSpacing.md) {
                            Text(String(localized: "Details"))
                                .font(VTypography.calloutBold)
                                .foregroundColor(VColors.textPrimary)

                            VStack(spacing: VSpacing.sm) {
                                DetailRow(label: String(localized: "Account"), value: account?.name ?? "Unknown")
                                DetailRow(label: String(localized: "Frequency"), value: frequencyLabel(rule.frequency))

                                if let note = rule.templateNote, !note.isEmpty {
                                    DetailRow(label: String(localized: "Note"), value: note)
                                }

                                if let payeeName = payee?.name {
                                    DetailRow(label: String(localized: "Payee"), value: payeeName)
                                }
                            }
                        }

                        // Upcoming Dates
                        UpcomingDatesView(rule: rule)

                        // Recent Transactions Section
                        if !recentTransactions.isEmpty {
                            VStack(alignment: .leading, spacing: VSpacing.md) {
                                Text(String(localized: "Recent Generated Transactions"))
                                    .font(VTypography.calloutBold)
                                    .foregroundColor(VColors.textPrimary)

                                VStack(spacing: VSpacing.sm) {
                                    ForEach(recentTransactions.prefix(5), id: \.id) { transaction in
                                        HStack(spacing: VSpacing.md) {
                                            VStack(alignment: .leading, spacing: VSpacing.xs) {
                                                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                                                    .font(VTypography.callout)
                                                    .foregroundColor(VColors.textPrimary)

                                                if let note = transaction.note, !note.isEmpty {
                                                    Text(note)
                                                        .font(VTypography.caption2)
                                                        .foregroundColor(VColors.textSecondary)
                                                }
                                            }

                                            Spacer()

                                            Text(transaction.amount.formatted(currencyCode: currencyCode))
                                                .font(VTypography.calloutBold)
                                                .foregroundColor(VColors.expense)
                                        }
                                        .padding(VSpacing.md)
                                        .background(VColors.secondaryBackground)
                                        .cornerRadius(VSpacing.cornerRadiusMD)
                                    }
                                }
                            }
                        }

                        Spacer()
                            .frame(height: VSpacing.xl)
                    }
                    .padding(VSpacing.lg)
                }
            } else if !isLoading {
                VStack(spacing: VSpacing.lg) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(VColors.textSecondary)

                    Text(String(localized: "Recurring Rule Not Found"))
                        .font(VTypography.title3)
                        .foregroundColor(VColors.textPrimary)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "Recurring Details"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showEditSheet) {
            if rule != nil {
                RecurringFormView(onDismiss: {
                    showEditSheet = false
                    Task {
                        await loadData()
                    }
                })
            }
        }
        .errorAlert(message: $errorMessage)
        .onAppear {
            Task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true

        do {
            if let rule = try await dependencies.recurringRuleRepository?.fetchByID(ruleID) {
                self.rule = rule

                if let categoryID = rule.templateCategoryID {
                    category = try await dependencies.categoryRepository?.fetchByID(categoryID)
                }

                if let accountID = rule.templateAccountID {
                    account = try await dependencies.accountRepository?.fetchByID(accountID)
                }

                if let payeeID = rule.templatePayeeID {
                    payee = try await dependencies.payeeRepository?.fetchByID(payeeID)
                }

                // Fetch recent transactions for this rule
                if let transactionRepo = dependencies.transactionRepository {
                    recentTransactions = try await transactionRepo.fetchForRecurringRule(ruleID)
                }
            }
        } catch {
            errorMessage = error.userFacingMessage(
                fallback: String(localized: "We couldn't load this recurring transaction right now.")
            )
        }

        isLoading = false
    }

    private func togglePause() {
        guard let rule = rule,
              let repo = dependencies.recurringRuleRepository else { return }

        Task {
            do {
                let pauseUseCase = PauseResumeRuleUseCase(repository: repo)
                try await pauseUseCase.execute(id: rule.id)
                await loadData()
            } catch {
                errorMessage = error.userFacingMessage(
                    fallback: String(localized: "We couldn't update this recurring transaction right now.")
                )
            }
        }
    }

    private var categoryColor: Color {
        if let colorHex = category?.colorHex {
            return Color(hex: colorHex) ?? .blue
        }
        return .blue
    }

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
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: VSpacing.md) {
            Text(label)
                .font(VTypography.callout)
                .foregroundColor(VColors.textSecondary)

            Spacer()

            Text(value)
                .font(VTypography.callout)
                .foregroundColor(VColors.textPrimary)
                .adaptiveLineLimit(1)
        }
        .padding(VSpacing.md)
        .background(VColors.tertiaryBackground)
        .cornerRadius(VSpacing.cornerRadiusMD)
    }
}

#Preview {
    RecurringDetailView(ruleID: UUID())
}
