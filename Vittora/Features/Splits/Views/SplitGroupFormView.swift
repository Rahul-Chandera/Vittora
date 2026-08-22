import SwiftUI
import VittoraCore

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
                Section {
                    TextField(
                        "",
                        text: $groupName,
                        prompt: Text(String(localized: "Group name"))
                            .foregroundStyle(VColors.placeholderText)
                    )
                        .accessibilityLabel(String(localized: "Group name"))
                } header: {
                    VFormSectionHeader(String(localized: "Group Name"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .headerProminence(.increased)

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
                                    .foregroundStyle(VColors.textPrimary)
                                Text(payee.name)
                                    .foregroundStyle(VColors.textPrimary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if selectedMemberIDs.count < 2 {
                        HStack(alignment: .firstTextBaseline, spacing: VSpacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .accessibilityHidden(true)
                            Text(String(localized: "Select at least 2 members."))
                                .font(VTypography.bodyBold)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(.primary)
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    VFormSectionHeader(String(localized: "Members (\(selectedMemberIDs.count) selected)"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .headerProminence(.increased)

                if let error {
                    Section {
                        VInlineErrorText(error)
                    }
                }
            }
            .tint(VColors.textPrimary)
            .navigationTitle(navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                    .vDialogCancelButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        guard canSave, !isSaving else { return }
                        Task { await save() }
                    }
                    .accessibilityRespondsToUserInteraction(canSave && !isSaving)
                    // Actually disabled, not just inert on tap. af8b34c8 removed
                    // .disabled() because SwiftUI dims to ~30% opacity and that
                    // fails the contrast audit; an explicit colour keeps the
                    // affordance AND passes at 5.07:1.
                    .disabled(!canSave || isSaving)
                    .vDialogConfirmButton()
                }
            }
        }
        .task {
            do {
                allPayees = try await dependencies.payeeRepository.fetchAll()
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
        isSaving = true
        error = nil
        let useCase = CreateSplitGroupUseCase(splitGroupRepository: dependencies.splitGroupRepository)
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
            appState.notifyChanged(.splits)
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
