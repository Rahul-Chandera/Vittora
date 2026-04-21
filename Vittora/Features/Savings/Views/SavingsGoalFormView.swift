import SwiftUI

struct SavingsGoalFormView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    let existingGoal: SavingsGoalEntity?
    let onSaved: () -> Void

    @State private var name = ""
    @State private var category: GoalCategory = .other
    @State private var targetString = ""
    @State private var currentString = ""
    @State private var hasDeadline = false
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 12, to: .now) ?? .now
    @State private var note = ""
    @State private var selectedColor = "#5856D6"
    @State private var isSaving = false
    @State private var error: String?

    private let palette = ["#5856D6","#FF2D55","#FF9500","#34C759","#007AFF","#AF52DE","#FF6B35","#00C7BE"]

    private var target: Decimal { Decimal(string: targetString.replacingOccurrences(of: ",", with: "")) ?? 0 }
    private var current: Decimal { Decimal(string: currentString.replacingOccurrences(of: ",", with: "")) ?? 0 }
    private var canSave: Bool { name.trimmingCharacters(in: .whitespaces).count >= 2 && target > 0 }
    private var isEditing: Bool { existingGoal != nil }

    init(existingGoal: SavingsGoalEntity? = nil, onSaved: @escaping () -> Void) {
        self.existingGoal = existingGoal
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic info
                Section(String(localized: "Goal")) {
                    TextField(String(localized: "e.g. Emergency Fund"), text: $name)

                    Picker(String(localized: "Category"), selection: $category) {
                        ForEach(GoalCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.systemImage).tag(cat)
                        }
                    }
                }

                // Amounts
                Section(String(localized: "Amounts")) {
                    HStack {
                        Text(String(localized: "Target"))
                        Spacer()
                        TextField("0", text: $targetString)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .textContentType(nil)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                    HStack {
                        Text(String(localized: "Already saved"))
                        Spacer()
                        TextField("0", text: $currentString)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .textContentType(nil)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                }

                // Deadline
                Section(String(localized: "Deadline")) {
                    Toggle(String(localized: "Set Deadline"), isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker(
                            String(localized: "Target Date"),
                            selection: $targetDate,
                            in: Date.now...,
                            displayedComponents: [.date]
                        )
                    }
                }

                // Color
                Section(String(localized: "Color")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VSpacing.sm) {
                            ForEach(palette, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex) ?? .purple)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if hex == selectedColor {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .onTapGesture { selectedColor = hex }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Note
                Section(String(localized: "Note")) {
                    TextField(String(localized: "Optional"), text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(VColors.expense)
                            .font(VTypography.caption1)
                    }
                }
            }
            .navigationTitle(isEditing ? String(localized: "Edit Goal") : String(localized: "New Goal"))
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
        .onAppear {
            if let goal = existingGoal {
                name = goal.name
                category = goal.category
                targetString = "\(goal.targetAmount)"
                currentString = goal.currentAmount > 0 ? "\(goal.currentAmount)" : ""
                hasDeadline = goal.targetDate != nil
                targetDate = goal.targetDate ?? Calendar.current.date(byAdding: .month, value: 12, to: .now) ?? .now
                note = goal.note ?? ""
                selectedColor = goal.colorHex
            }
        }
        .onChange(of: error) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
            }
        }
    }

    private func save() async {
        guard let repo = dependencies.savingsGoalRepository else { return }
        isSaving = true
        error = nil
        let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: repo)
        do {
            if let existing = existingGoal {
                var updated = existing
                updated.name = name.trimmingCharacters(in: .whitespaces)
                updated.category = category
                updated.targetAmount = target
                updated.currentAmount = current
                updated.targetDate = hasDeadline ? targetDate : nil
                updated.note = note.isEmpty ? nil : note
                updated.colorHex = selectedColor
                try await useCase.executeUpdate(updated)
            } else {
                _ = try await useCase.executeCreate(
                    name: name,
                    category: category,
                    targetAmount: target,
                    currentAmount: current,
                    targetDate: hasDeadline ? targetDate : nil,
                    linkedAccountID: nil,
                    note: note.isEmpty ? nil : note,
                    colorHex: selectedColor
                )
            }
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
