import SwiftUI
import VittoraCore

struct RecurringListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel: RecurringListViewModel?
    @State private var showAddSheet = false

    var body: some View {
        ZStack {
            VColors.groupedBackground.ignoresSafeArea()

            if let viewModel = viewModel {
                if let error = viewModel.error, viewModel.rules.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "Unable to Load"), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button(String(localized: "Try Again")) {
                            viewModel.error = nil
                            Task { await viewModel.loadRules() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VColors.primary)
                    }
                } else {
                    VStack(spacing: 0) {
                    // Cost Summary Card
                    if let costSummary = viewModel.costSummary {
                        VStack(alignment: .leading, spacing: VSpacing.md) {
                            Text(String(localized: "Monthly Spend"))
                                .font(VTypography.callout)
                                .foregroundColor(VColors.textPrimary)

                            let amountLayout = dynamicTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.md))
                                : AnyLayout(HStackLayout(spacing: VSpacing.xl))
                            amountLayout {
                                VStack(alignment: .leading, spacing: VSpacing.xs) {
                                    Text(costSummary.monthlyCost.formatted(currencyCode: currencyCode))
                                        .font(VTypography.amountLarge)
                                        .amountScaling()
                                        .foregroundColor(VColors.textPrimary)

                                    Text(String(localized: "per month"))
                                        .font(VTypography.caption2)
                                        .foregroundColor(VColors.textPrimary)
                                }

                                if !dynamicTypeSize.isAccessibilitySize {
                                    Spacer()
                                }

                                VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: VSpacing.xs) {
                                    Text(costSummary.annualCost.formatted(currencyCode: currencyCode))
                                        .font(VTypography.bodyBold)
                                        .foregroundColor(VColors.textPrimary)

                                    Text(String(localized: "per year"))
                                        .font(VTypography.caption2)
                                        .foregroundColor(VColors.textPrimary)
                                }
                            }

                            Divider()
                                .padding(.vertical, VSpacing.md)

                            HStack {
                                Image(systemName: "repeat")
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(VColors.textPrimary)
                                    .accessibilityHidden(true)

                                Text(String(localized: "\(costSummary.ruleCount) active \(costSummary.ruleCount == 1 ? "subscription" : "subscriptions")"))
                                    .font(VTypography.caption1)
                                    .foregroundColor(VColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer()
                            }
                        }
                        .padding(VSpacing.lg)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String(localized: "Recurring spending summary"))
                        .accessibilityValue(
                            String(
                                localized: "\(costSummary.monthlyCost.formatted(currencyCode: currencyCode)) per month, \(costSummary.annualCost.formatted(currencyCode: currencyCode)) per year, \(costSummary.ruleCount) active"
                            )
                        )
                        .background(VColors.secondaryGroupedBackground)
                        .cornerRadius(VSpacing.cornerRadiusMD)
                        .padding(VSpacing.lg)
                    }

                    if viewModel.rules.isEmpty {
                        ContentUnavailableView {
                            Label(String(localized: "No Recurring Transactions"), systemImage: "repeat.circle")
                        } description: {
                            Text(String(localized: "Create your first recurring transaction to get started"))
                        } actions: {
                            Button(String(localized: "Add Recurring Transaction")) {
                                showAddSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(VColors.primary)
                        }
                    } else {
                        List {
                            ForEach(viewModel.grouped, id: \.label) { group in
                                Section {
                                    ForEach(group.rules, id: \.id) { rule in
                                        NavigationLink {
                                            RecurringDetailView(ruleID: rule.id)
                                        } label: {
                                            RecurringRowView(rule: rule, category: viewModel.category(for: rule))
                                        }
                                        .accessibilityIdentifier("recurring-row-\(rule.id.uuidString)")
                                        .contextMenu {
                                            NavigationLink {
                                                RecurringDetailView(ruleID: rule.id)
                                            } label: {
                                                Label(String(localized: "Edit"), systemImage: "pencil")
                                            }
                                            Button {
                                                Task {
                                                    await viewModel.togglePause(id: rule.id)
                                                    await dependencies.refreshRecurringAndDebtReminders()
                                                }
                                            } label: {
                                                Label(
                                                    rule.isActive ? String(localized: "Pause") : String(localized: "Resume"),
                                                    systemImage: rule.isActive ? "pause.circle.fill" : "play.circle.fill"
                                                )
                                            }
                                            Button(role: .destructive) {
                                                Task {
                                                    await viewModel.deleteRule(id: rule.id)
                                                    await dependencies.refreshRecurringAndDebtReminders()
                                                    appState.notifyChanged(.recurring)
                                                }
                                            } label: {
                                                Label(String(localized: "Delete"), systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                Task {
                                                    await viewModel.togglePause(id: rule.id)
                                                    await dependencies.refreshRecurringAndDebtReminders()
                                                }
                                            } label: {
                                                Label(
                                                    rule.isActive ? "Pause" : "Resume",
                                                    systemImage: rule.isActive ? "pause.circle.fill" : "play.circle.fill"
                                                )
                                            }
                                            .tint(VColors.warning)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                Task {
                                                    await viewModel.deleteRule(id: rule.id)
                                                    await dependencies.refreshRecurringAndDebtReminders()
                                                    appState.notifyChanged(.recurring)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash.fill")
                                            }
                                        }
                                    }
                                } header: {
                                    Text(group.label)
                                        .font(VTypography.calloutBold)
                                        .foregroundStyle(VColors.textPrimary)
                                }
                            }
                        }
                        #if os(iOS)
                        .listStyle(.insetGrouped)
                        #else
                        .listStyle(.inset)
                        #endif
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    }
                }
            } else {
                ProgressView()
            }
        }
        // Clearance for the floating tab bar. safeAreaPadding, not
        // safeAreaInset: an inset paints an opaque view OVER the list, and
        // rows passing behind it are sliced mid-glyph. The Appearance
        // screen's Live Preview card was cut that way, and the audit's
        // contrast sampler reads the surviving sliver as failing text.
        // Padding reserves the same space without drawing.
        //
        // The plain ScrollView screens keep their inset: removing it there
        // lets content render in the gutter below the tab bar, which the
        // audit reports as text with no accessible element.
        .safeAreaPadding(.bottom, 72)
        .navigationTitle(String(localized: "Recurring Transactions"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel(String(localized: "Add Recurring Transaction"))
                .accessibilityHint(String(localized: "Opens the recurring transaction form"))
                .accessibilityIdentifier("recurring-add-button")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            RecurringFormView(onDismiss: {
                showAddSheet = false
                Task {
                    await viewModel?.loadRules()
                }
            })
        }
        .onAppear {
            if viewModel == nil {
                setupViewModel()
            }
            Task {
                await viewModel?.loadRules()
            }
        }
        .task(id: appState.refreshVersion(for: .recurring)) {
            guard viewModel != nil, appState.refreshVersion(for: .recurring) > 0 else { return }
            await viewModel?.loadRules()
        }
    }

    private func setupViewModel() {
        viewModel = dependencies.makeRecurringListViewModel()
    }
}

#Preview {
    NavigationStack {
        RecurringListView()
            .withNavigationDestinations()
    }
}
