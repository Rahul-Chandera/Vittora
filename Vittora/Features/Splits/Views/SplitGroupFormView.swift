import SwiftUI

struct SplitGroupFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var groupName = ""
    @State private var selectedMemberIDs: Set<UUID> = []
    @State private var allPayees: [PayeeEntity] = []
    @State private var isSaving = false
    @State private var error: String?

    /// If editing an existing group
    let existingGroup: SplitGroup?
    let onSaved: () -> Void

    init(existingGroup: SplitGroup? = nil, onSaved: @escaping () -> Void) {
        self.existingGroup = existingGroup
        self.onSaved = onSaved
    }

    private var canSave: Bool {
        groupName.trimmingCharacters(in: .whitespaces).count >= 2 && selectedMemberIDs.count >= 2
    }

    private var navigationTitle: String {
        existingGroup == nil
            ? String(localized: "New Group")
            : String(localized: "Edit Group")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Group Name")) {
                    TextField(String(localized: "e.g. Trip to Goa"), text: $groupName)
                }

                Section {
                    ForEach(allPayees) { payee in
                        Button {
                            if selectedMemberIDs.contains(payee.id) {
                                selectedMemberIDs.remove(payee.id)
                            } else {
                                selectedMemberIDs.insert(payee.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedMemberIDs.contains(payee.id)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .foregroundStyle(selectedMemberIDs.contains(payee.id)
                                                     ? VColors.primary : VColors.textSecondary)
                                Text(payee.name)
                                    .foregroundStyle(VColors.textPrimary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(String(localized: "Members (\(selectedMemberIDs.count) selected)"))
                } footer: {
                    if selectedMemberIDs.count < 2 {
                        VInlineErrorText(String(localized: "Select at least 2 members."))
                    }
                }

                if let error {
                    Section {
                        VInlineErrorText(error)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        Task { await save() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
        .task {
            guard let payeeRepo = dependencies.payeeRepository else { return }
            do {
                allPayees = try await payeeRepo.fetchAll()
            } catch {
                self.error = error.localizedDescription
            }
            if let existing = existingGroup {
                groupName = existing.name
                selectedMemberIDs = Set(existing.memberIDs)
            }
        }
        .onChange(of: error) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
            }
        }
    }

    private func save() async {
        guard let repo = dependencies.splitGroupRepository else { return }
        isSaving = true
        error = nil
        let useCase = CreateSplitGroupUseCase(splitGroupRepository: repo)
        do {
            if let existing = existingGroup {
                _ = try await useCase.executeUpdate(
                    group: existing,
                    name: groupName,
                    memberIDs: Array(selectedMemberIDs)
                )
            } else {
                _ = try await useCase.execute(name: groupName, memberIDs: Array(selectedMemberIDs))
            }
            appState.notifyDataChanged()
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
