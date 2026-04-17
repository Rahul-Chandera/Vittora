import SwiftUI

struct RecurringDetailView: View {
    @Environment(\.dependencies) var dependencies
    let ruleID: UUID
    @State private var rule: RecurringRuleEntity?
    @State private var category: CategoryEntity?
    @State private var account: AccountEntity?
    @State private var payee: PayeeEntity?
    @State private var recentTransactions: [TransactionEntity] = []
    @State private var isLoading = true
    @State private var showEditSheet = false

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
                                    Text(category?.name ?? "Uncategorized")
                                        .font(VTypography.title2)
                                        .foregroundColor(VColors.textPrimary)

                                    Text(frequencyLabel(rule.frequency))
                                        .font(VTypography.callout)
                                        .foregroundColor(VColors.textSecondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: VSpacing.xs) {
                                    Text(String(format: "$%.2f", Double(truncating: rule.templateAmount as NSDecimalNumber)))
                                        .font(VTypography.amountMedium)
                                        .foregroundColor(VColors.expense)

                                    Text("per transaction")
                                        .font(VTypography.caption2)
                                        .foregroundColor(VColors.textSecondary)
                                }
                            }

                            Divider()

                            // Status and dates
                            HStack {
                                Label(
                                    rule.isActive ? "Active" : "Paused",
                                    systemImage: rule.isActive ? "checkmark.circle.fill" : "pause.circle.fill"
                                )
                                .font(VTypography.callout)
                                .foregroundColor(rule.isActive ? .green : .orange)

                                Spacer()

                                Text("Next: \(rule.nextDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(VTypography.callout)
                                    .foregroundColor(VColors.textSecondary)
                            }

                            if let endDate = rule.endDate {
                                Divider()

                                HStack {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(VColors.warning)

                                    Text("Ends: \(endDate.formatted(date: .abbreviated, time: .omitted))")
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
                                    rule.isActive ? "Pause" : "Resume",
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
                            Text("Details")
                                .font(VTypography.calloutBold)
                                .foregroundColor(VColors.textPrimary)

                            VStack(spacing: VSpacing.sm) {
                                DetailRow(label: "Account", value: account?.name ?? "Unknown")
                                DetailRow(label: "Frequency", value: frequencyLabel(rule.frequency))

                                if let note = rule.templateNote, !note.isEmpty {
                                    DetailRow(label: "Note", value: note)
                                }

                                if let payeeName = payee?.name {
                                    DetailRow(label: "Payee", value: payeeName)
                                }
                            }
                        }

                        // Upcoming Dates
                        UpcomingDatesView(rule: rule)

                        // Recent Transactions Section
                        if !recentTransactions.isEmpty {
                            VStack(alignment: .leading, spacing: VSpacing.md) {
                                Text("Recent Generated Transactions")
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

                                            Text(String(format: "$%.2f", Double(truncating: transaction.amount as NSDecimalNumber)))
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

                    Text("Recurring Rule Not Found")
                        .font(VTypography.title3)
                        .foregroundColor(VColors.textPrimary)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Recurring Details")
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
                    let allTransactions = try await transactionRepo.fetchAll(filter: nil)
                    recentTransactions = allTransactions
                        .filter { $0.recurringRuleID == ruleID }
                        .sorted { $0.date > $1.date }
                }
            }
        } catch {
            // Silent error for now
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
                // Handle error
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
            return "Daily"
        case .weekly:
            return "Weekly"
        case .biweekly:
            return "Bi-weekly"
        case .monthly:
            return "Monthly"
        case .quarterly:
            return "Quarterly"
        case .yearly:
            return "Yearly"
        case .custom(let days):
            return "Every \(days) days"
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
                .lineLimit(1)
        }
        .padding(VSpacing.md)
        .background(VColors.tertiaryBackground)
        .cornerRadius(VSpacing.cornerRadiusMD)
    }
}

#Preview {
    RecurringDetailView(ruleID: UUID())
}
