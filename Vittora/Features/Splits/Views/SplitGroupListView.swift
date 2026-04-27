import SwiftUI

struct SplitGroupListView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: SplitGroupListViewModel?
    @State private var showAddGroup = false
    @State private var selectedGroupID: UUID?

    var body: some View {
        NavigationStack {
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
                }
            }
            .navigationDestination(item: $selectedGroupID) { groupID in
                if let summary = vm?.summaries.first(where: { $0.id == groupID }) {
                    SplitGroupDetailView(group: summary.group)
                }
            }
        }
        .task {
            if vm == nil {
                guard let splitRepo = dependencies.splitGroupRepository,
                      let payeeRepo = dependencies.payeeRepository else { return }
                vm = SplitGroupListViewModel(
                    fetchGroupsUseCase: FetchSplitGroupsUseCase(
                        splitGroupRepository: splitRepo,
                        payeeRepository: payeeRepo
                    ),
                    createGroupUseCase: CreateSplitGroupUseCase(splitGroupRepository: splitRepo),
                    splitGroupRepository: splitRepo
                )
                await vm?.load()
            }
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
                    }
                }
                .padding(VSpacing.screenPadding)
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
    let summary: SplitGroupSummary

    var body: some View {
        VCard {
            HStack(spacing: VSpacing.md) {
                // Icon
                RoundedRectangle(cornerRadius: 12)
                    .fill(VColors.primary.opacity(0.12))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "person.3.fill")
                            .font(.title3)
                            .foregroundStyle(VColors.primary)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.group.name)
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)

                    HStack(spacing: 4) {
                        Text(String(localized: "\(summary.group.memberIDs.count) members"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)

                        if summary.outstandingCount > 0 {
                            Text("·")
                                .foregroundStyle(VColors.textSecondary)
                            Text(String(localized: "\(summary.outstandingCount) outstanding"))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.expense)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    VAmountText(expense: summary.totalExpenses, size: .body)

                    Text(String(localized: "total"))
                        .font(VTypography.caption2)
                        .foregroundStyle(VColors.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(VColors.textSecondary)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    SplitGroupListView()
}
