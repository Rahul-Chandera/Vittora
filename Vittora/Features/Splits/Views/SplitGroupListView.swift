import SwiftUI
import VittoraCore

struct SplitGroupListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @State private var vm: SplitGroupListViewModel?
    @State private var showAddGroup = false
    @State private var selectedGroupID: UUID?

    var body: some View {
        ZStack {
            if let vm {
                if vm.isLoading && vm.summaries.isEmpty {
                    ProgressView().tint(VColors.primary)
                } else if let error = vm.error {
                    ContentUnavailableView {
                        Label(String(localized: "Unable to Load"), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button(String(localized: "Try Again")) {
                            vm.error = nil
                            Task { await vm.load() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VColors.primary)
                    }
                } else {
                    listContent(vm)
                }
            }
        }
        .background(VColors.background)
        .navigationTitle(String(localized: "Split Expenses"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddGroup = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Add split group"))
                .accessibilityHint(String(localized: "Opens the split group form"))
                .accessibilityIdentifier("split-group-add-button")
            }
        }
        .navigationDestination(item: $selectedGroupID) { groupID in
            if let summary = vm?.summaries.first(where: { $0.id == groupID }) {
                SplitGroupDetailView(group: summary.group)
            }
        }
        .task {
            if vm == nil {
                vm = dependencies.makeSplitGroupListViewModel()
                await vm?.load()
            }
        }
        .task(id: appState.refreshVersion(for: .splits)) {
            guard vm != nil, appState.refreshVersion(for: .splits) > 0 else { return }
            await vm?.load()
        }
        .task(id: appState.pendingSplitGroupID) {
            guard let groupID = appState.pendingSplitGroupID else { return }
            await vm?.load()
            guard vm?.summaries.contains(where: { $0.id == groupID }) == true else { return }
            selectedGroupID = groupID
            appState.clearPendingSplitGroupID()
        }
        .sheet(isPresented: $showAddGroup) {
            SplitGroupFormView {
                Task { await vm?.load() }
            }
        }
        .refreshable {
            await vm?.load()
        }
    }

    @ViewBuilder
    private func listContent(_ vm: SplitGroupListViewModel) -> some View {
        if vm.summaries.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: VSpacing.md) {
                    ForEach(vm.summaries) { summary in
                        Button {
                            selectedGroupID = summary.id
                        } label: {
                            GroupRowView(summary: summary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("split-group-row-\(summary.id)")
                    }
                }
                .padding(VSpacing.screenPadding)
            }
            .safeAreaInset(edge: .bottom) {
                // Clearance for the floating tab bar, painted in THIS screen's page
            // colour — plain background, because this screen is not grouped.
            VColors.background
                    .frame(height: 72)
                    .allowsHitTesting(false)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(String(localized: "No groups yet"), systemImage: "person.3.fill")
        } description: {
            Text(String(localized: "Create a group to track shared expenses with friends or family"))
        } actions: {
            Button(String(localized: "Create Group")) {
                showAddGroup = true
            }
            .buttonStyle(.borderedProminent)
            .tint(VColors.primary)
        }
    }
}

// MARK: - Group Row

private struct GroupRowView: View {
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let summary: SplitGroupSummary

    var body: some View {
        VCard {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.md))
                : AnyLayout(HStackLayout(spacing: VSpacing.md))
            layout {
                // Icon
                RoundedRectangle(cornerRadius: 12)
                    .fill(VColors.primary.opacity(0.12))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "person.3.fill")
                            .font(.title3)
                            .foregroundStyle(VColors.primaryOnSurface)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.group.name)
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    let statusLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.xxs))
                        : AnyLayout(HStackLayout(spacing: 4))
                    statusLayout {
                        Text(String(localized: "\(summary.group.memberIDs.count) members"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textPrimary)

                        if summary.outstandingCount > 0 {
                            if !dynamicTypeSize.isAccessibilitySize {
                                // Decorative separator — see GroupExpenseRowView.
                                Text("·")
                                    .foregroundStyle(VColors.textPrimary)
                                    .accessibilityHidden(true)
                            }
                            Text(String(localized: "\(summary.outstandingCount) outstanding"))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textPrimary)
                        }
                    }
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }

                VStack(alignment: .trailing, spacing: 4) {
                    VAmountText(expense: summary.totalExpenses, size: .body)

                    Text(String(localized: "total"))
                        .font(VTypography.caption2)
                        .foregroundStyle(VColors.textPrimary)
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(VColors.textPrimary)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.group.name)
        .accessibilityValue(
            String(
                localized: "\(summary.group.memberIDs.count) members, \(summary.outstandingCount) outstanding, \(summary.totalExpenses.formatted(.currency(code: currencyCode))) total"
            )
        )
        .accessibilityHint(String(localized: "Opens split group details"))
    }
}

#Preview {
    NavigationStack {
        SplitGroupListView()
    }
}
