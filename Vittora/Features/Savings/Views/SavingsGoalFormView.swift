import SwiftUI
import VittoraCore

struct SavingsGoalFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode

    let existingGoal: SavingsGoalEntity?
    let onSaved: () -> Void

    @State private var name = ""
    @State private var category: GoalCategory = .other
    @State private var targetString = ""
    @State private var currentString = ""
    @State private var hasDeadline = false
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 12, to: .now) ?? .now
    @State private var note = ""
    @State private var isEmergencyFund = false
    @State private var selectedColor = "#5856D6"
    @State private var isSaving = false
    @State private var error: String?

    private let palette = ["#5856D6","#FF2D55","#FF9500","#34C759","#007AFF","#AF52DE","#FF6B35","#00C7BE"]

    private var parsedTarget: Decimal? { Decimal(localizedAmount: targetString) }
    private var parsedCurrent: Decimal? { Decimal(localizedAmount: currentString) }
    private var canSave: Bool {
        guard let parsedTarget, parsedTarget > 0 else { return false }
        return name.trimmingCharacters(in: .whitespaces).count >= 2
    }
    private var isEditing: Bool { existingGoal != nil }

    private var allocationPreview: SavingsAllocationSnapshot? {
        guard let parsedTarget, parsedTarget > 0 else { return nil }
        let current = parsedCurrent ?? 0
        guard current < parsedTarget else { return nil }
        let snapshot = SavingsAllocationMath.snapshot(
            targetAmount: parsedTarget,
            currentAmount: current,
            targetDate: hasDeadline ? targetDate : nil
        )
        guard snapshot.monthlyRequired != nil || snapshot.projectedCompletionDate != nil else { return nil }
        return snapshot
    }

    init(existingGoal: SavingsGoalEntity? = nil, onSaved: @escaping () -> Void) {
        self.existingGoal = existingGoal
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section {
                    TextField(String(localized: "Goal name"), text: $name)
                        .accessibilityLabel(String(localized: "Goal name"))

                    Picker(String(localized: "Category"), selection: $category) {
                        ForEach(GoalCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.systemImage).tag(cat)
                        }
                    }
                } header: {
                    sectionHeader(String(localized: "Goal"))
                }
                .headerProminence(.increased)

                // Amounts
                Section {
                    amountRow(
                        title: String(localized: "Target"),
                        accessibilityLabel: String(localized: "Target amount"),
                        text: $targetString
                    )
                    amountRow(
                        title: String(localized: "Already saved"),
                        accessibilityLabel: String(localized: "Amount already saved"),
                        text: $currentString
                    )
                } header: {
                    sectionHeader(String(localized: "Amounts"))
                }
                .headerProminence(.increased)

                Section {
                    Toggle(String(localized: "Count toward emergency fund"), isOn: $isEmergencyFund)
                } footer: {
                    Text(String(localized: "The saved amount in this goal will count toward your emergency-fund coverage."))
                        .font(.body)
                        .foregroundStyle(VColors.textPrimary)
                }

                // Deadline
                Section {
                    Toggle(String(localized: "Set Deadline"), isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker(
                            String(localized: "Target Date"),
                            selection: $targetDate,
                            in: Date.now...,
                            displayedComponents: [.date]
                        )
                    }
                } header: {
                    sectionHeader(String(localized: "Deadline"))
                }
                .headerProminence(.increased)

                if let preview = allocationPreview {
                    Section {
                        if let monthly = preview.monthlyRequired {
                            HStack {
                                Text(String(localized: "Suggested monthly"))
                                Spacer()
                                Text(monthly.formatted(.currency(code: currencyCode)) + String(localized: "/month"))
                                    .font(VTypography.bodyBold)
                                .foregroundStyle(VColors.textPrimary)
                            }
                        }
                        if let projected = preview.projectedCompletionDate {
                            HStack {
                                Text(String(localized: "Projected completion"))
                                Spacer()
                                Text(projected.formatted(date: .long, time: .omitted))
                                    .font(VTypography.bodyBold)
                            }
                        }
                        if let months = preview.remainingMonths, months > 0 {
                            Text(String(localized: "Based on \(months) month(s) until your deadline."))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textPrimary)
                        }
                    } header: {
                        sectionHeader(String(localized: "Savings Plan"))
                    }
                    .headerProminence(.increased)
                }

                // Color
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VSpacing.sm) {
                            ForEach(palette, id: \.self) { hex in
                                Button {
                                    selectedColor = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex) ?? .purple)
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            if hex == selectedColor {
                                                Image(systemName: "checkmark")
                                                    .font(.body.bold())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    String(
                                        localized: "Goal color \((palette.firstIndex(of: hex) ?? 0) + 1)"
                                    )
                                )
                                .accessibilityValue(
                                    hex == selectedColor
                                    ? String(localized: "Selected")
                                    : String(localized: "Not selected")
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    sectionHeader(String(localized: "Color"))
                }
                .headerProminence(.increased)

                // Note
                Section {
                    TextField(String(localized: "Optional"), text: $note, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    sectionHeader(String(localized: "Note"))
                }
                .headerProminence(.increased)

                if let error {
                    Section {
                        VInlineErrorText(error)
                    }
                }
            }
            .tint(VColors.textCursor)
            .navigationTitle(isEditing ? String(localized: "Edit Goal") : String(localized: "New Goal"))
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
                    // See SplitGroupFormView for why the colour is explicit.
                    .disabled(!canSave || isSaving)
                    .vDialogConfirmButton()
                }
            }
        }
        .onAppear {
            if let goal = existingGoal {
                name = goal.name
                category = goal.category
                targetString = "\(goal.targetAmount)"
                currentString = goal.currentAmount > 0 ? "\(goal.currentAmount)" : ""
                hasDeadline = goal.targetDate != nil
                targetDate = goal.targetDate ?? Calendar.current.date(byAdding: .month, value: 12, to: .now) ?? .now
                note = goal.note ?? ""
                isEmergencyFund = goal.isEmergencyFund
                selectedColor = goal.colorHex
            }
        }
        .onChange(of: error) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        VFormSectionHeader(title)
    }

    private func amountRow(
        title: String,
        accessibilityLabel: String,
        text: Binding<String>
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title)
                Spacer()
                amountField(accessibilityLabel: accessibilityLabel, text: text)
                    .frame(width: 140)
            }
            VStack(alignment: .leading, spacing: VSpacing.xs) {
                Text(title)
                amountField(accessibilityLabel: accessibilityLabel, text: text)
            }
        }
    }

    private func amountField(
        accessibilityLabel: String,
        text: Binding<String>
    ) -> some View {
        TextField(
            "",
            text: text,
            prompt: Text("0").foregroundStyle(VColors.placeholderText)
        )
            #if os(iOS)
            .keyboardType(.decimalPad)
            .textContentType(nil)
            #endif
            .multilineTextAlignment(.trailing)
            .accessibilityLabel(accessibilityLabel)
    }

    private func save() async {
        guard let parsedTarget, parsedTarget > 0 else {
            error = String(localized: "Please enter a valid target amount.")
            return
        }
        if !currentString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           parsedCurrent == nil {
            error = String(localized: "Please enter a valid current amount.")
            return
        }
        let currentAmount = parsedCurrent ?? 0
        isSaving = true
        error = nil
        let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: dependencies.savingsGoalRepository)
        do {
            if let existing = existingGoal {
                var updated = existing
                updated.name = name.trimmingCharacters(in: .whitespaces)
                updated.category = category
                updated.targetAmount = parsedTarget
                updated.currentAmount = currentAmount
                updated.targetDate = hasDeadline ? targetDate : nil
                updated.note = note.isEmpty ? nil : note
                updated.isEmergencyFund = isEmergencyFund
                updated.colorHex = selectedColor
                try await useCase.executeUpdate(updated)
            } else {
                _ = try await useCase.executeCreate(
                    name: name,
                    category: category,
                    targetAmount: parsedTarget,
                    currentAmount: currentAmount,
                    targetDate: hasDeadline ? targetDate : nil,
                    linkedAccountID: nil,
                    note: note.isEmpty ? nil : note,
                    colorHex: selectedColor,
                    isEmergencyFund: isEmergencyFund
                )
            }
            appState.notifyChanged(.savings)
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
