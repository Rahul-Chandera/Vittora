import SwiftUI
import VittoraCore

/// Financial health score (M3.2.4).
///
/// Presents a number with the figures behind it, never a verdict. The plan's
/// scope note rules out financial advice, so nothing here tells the user what to
/// do — each component states what was measured and what it came to, and the
/// disclaimer says plainly that it is a description of their own records.
struct FinancialHealthScoreReportView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var vm: FinancialHealthScoreViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VSpacing.sectionSpacing) {
                if let vm {
                    if vm.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if let result = vm.result {
                        scoreCard(result)
                        componentsCard(result)
                        if !result.unmeasured.isEmpty {
                            unmeasuredCard(result)
                        }
                        disclaimer
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
        .safeAreaInset(edge: .bottom) {
            // Clearance for the floating tab bar. Without it the last card runs
            // under the bar — caught on iPhone 17 Pro Max / iOS 26.5, where the
            // What If card's final caveat line was clipped by it.
            //
            // Taller at accessibility sizes for the same reason the other report
            // screens are: the bar grows with the type size.
            VColors.groupedBackground
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 140 : 72)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VColors.groupedBackground)
        .navigationTitle(String(localized: "Financial Health"))
        .task {
            if vm == nil {
                vm = FinancialHealthScoreViewModel(
                    transactionRepository: dependencies.transactionRepository,
                    budgetRepository: dependencies.budgetRepository,
                    debtRepository: dependencies.debtRepository
                )
            }
            await vm?.load()
        }
    }

    @ViewBuilder
    private func scoreCard(_ result: FinancialHealthScoreEngine.Result) -> some View {
        VCard {
            VStack(spacing: VSpacing.sm) {
                if let score = result.overallScore {
                    Text("\(score)")
                        .font(VTypography.amountLarge)
                        .foregroundStyle(VColors.textPrimary)
                        .monospacedDigit()
                        .accessibilityIdentifier("health-score-value")
                    Text(String(localized: "out of 100"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    // How many of the three inputs it rests on. A score from one
                    // component means something quite different from one built
                    // on all three, so it is never shown bare.
                    Text(String(localized: "Based on \(result.measuredCount) of 3 measures."))
                        .font(VTypography.caption2)
                        .foregroundStyle(VColors.textSecondary)
                } else {
                    Text(String(localized: "Not enough recorded yet"))
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                    Text(String(localized: "Add a budget, or record this month's income, and a score will appear."))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    private func componentsCard(_ result: FinancialHealthScoreEngine.Result) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                ForEach(result.components) { component in
                    VStack(alignment: .leading, spacing: VSpacing.xs) {
                        HStack {
                            Text(title(for: component.id))
                                .font(VTypography.body)
                                .foregroundStyle(VColors.textPrimary)
                            Spacer()
                            Text("\(component.score)")
                                .font(VTypography.bodyBold)
                                .foregroundStyle(VColors.textPrimary)
                                .monospacedDigit()
                        }
                        ProgressView(value: Double(component.score), total: 100)
                            .tint(VColors.primary)
                            .accessibilityHidden(true)
                        // The figures the score came from, so it is auditable.
                        Text(component.detail)
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(localized: "\(title(for: component.id)): \(component.score) out of 100. \(component.detail)")
                    )
                }
            }
        }
    }

    private func unmeasuredCard(_ result: FinancialHealthScoreEngine.Result) -> some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.xs) {
                Text(String(localized: "Not Scored"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)
                ForEach(result.unmeasured, id: \.self) { reason in
                    Text(reason)
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var disclaimer: some View {
        Text(String(localized: "This score describes your own records for this month. It is not financial advice, and it does not compare you with anyone else."))
            .font(VTypography.caption2)
            .foregroundStyle(VColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("health-score-disclaimer")
    }

    private func title(for kind: FinancialHealthScoreEngine.Component.Kind) -> String {
        switch kind {
        case .budgetAdherence: String(localized: "Budget adherence")
        case .savingsRate:     String(localized: "Savings rate")
        case .debtRatio:       String(localized: "Debt level")
        }
    }
}
