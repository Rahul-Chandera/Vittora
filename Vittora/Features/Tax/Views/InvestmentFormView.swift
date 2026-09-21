import SwiftUI
import VittoraCore

/// Add or edit a tracked investment (M2.4.5).
struct InvestmentFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode

    let investment: Investment?
    let onSave: (Investment) async -> Void

    @State private var name: String = ""
    @State private var amountText: String = ""
    @State private var instrumentID: String = ""
    @State private var hasMaturityDate = true
    @State private var maturityDate: Date = .now
    @State private var remindsOnMaturity = true
    @State private var note: String = ""

    private var amount: Decimal? { Decimal(localizedAmount: amountText) }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (amount ?? 0) > 0
    }

    private var selectedInstrument: India80CInstrument? {
        India80CInstrumentTable.all.first { $0.id == instrumentID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Name"), text: $name)
                        .accessibilityIdentifier("investment-name-field")

                    HStack {
                        Text(String(localized: "Amount"))
                        Spacer()
                        TextField("", text: $amountText, prompt: Text("0").foregroundStyle(VColors.placeholderText))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel(String(localized: "Amount"))
                            .accessibilityHint(String(localized: "Amount in \(currencyCode)"))
                            .accessibilityIdentifier("investment-amount-field")
                    }

                    Picker(String(localized: "Instrument"), selection: $instrumentID) {
                        Text(String(localized: "Other")).tag("")
                        ForEach(India80CInstrumentTable.all) { instrument in
                            Text(instrument.name).tag(instrument.id)
                        }
                    }
                    .accessibilityIdentifier("investment-instrument-picker")
                } header: {
                    VFormSectionHeader(String(localized: "Investment"))
                }

                Section {
                    Toggle(String(localized: "Has a maturity date"), isOn: $hasMaturityDate)
                        .accessibilityIdentifier("investment-has-maturity-toggle")
                    if hasMaturityDate {
                        DatePicker(
                            String(localized: "Matures on"),
                            selection: $maturityDate,
                            displayedComponents: .date
                        )
                        .accessibilityIdentifier("investment-maturity-date-picker")
                        Toggle(String(localized: "Remind me before it matures"), isOn: $remindsOnMaturity)
                            .accessibilityIdentifier("investment-reminder-toggle")
                    }
                } header: {
                    VFormSectionHeader(String(localized: "Maturity"))
                } footer: {
                    Text(
                        hasMaturityDate
                            ? String(localized: "You'll get a reminder \(ScheduleInvestmentMaturityRemindersUseCase.leadDays) days before the date.")
                            : String(localized: "Some lock-ins are tied to your age rather than a date — NPS Tier-I runs to 60. Those appear on the timeline without a countdown.")
                    )
                    .foregroundStyle(VColors.textSecondary)
                }

                Section {
                    TextField(String(localized: "Note"), text: $note, axis: .vertical)
                        .accessibilityIdentifier("investment-note-field")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(
                investment == nil
                    ? String(localized: "Add Investment")
                    : String(localized: "Edit Investment")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        Task {
                            await onSave(makeInvestment())
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("investment-save-button")
                }
            }
            .onAppear(perform: populate)
            .onChange(of: instrumentID) { _, _ in applyInstrumentDefaults() }
        }
    }

    private func populate() {
        guard let investment else { return }
        name = investment.name
        amountText = "\(investment.amount)"
        instrumentID = investment.instrumentID
        hasMaturityDate = investment.maturityDate != nil
        maturityDate = investment.maturityDate ?? .now
        remindsOnMaturity = investment.remindsOnMaturity
        note = investment.note ?? ""
    }

    /// Picking a known instrument fills in what is statutory about it — the lock-in term
    /// and the section — rather than making the user look it up. Only on a new record, so
    /// an edit never silently overwrites a date the user chose.
    private func applyInstrumentDefaults() {
        guard investment == nil, let instrument = selectedInstrument else { return }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = instrument.name
        }
        if let years = instrument.lockInYears {
            hasMaturityDate = true
            maturityDate = Calendar.current.date(byAdding: .year, value: years, to: .now) ?? maturityDate
        } else {
            hasMaturityDate = false
        }
    }

    private func makeInvestment() -> Investment {
        Investment(
            id: investment?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            instrumentID: instrumentID,
            amount: amount ?? 0,
            sectionKey: selectedInstrument?.sections.first ?? investment?.sectionKey ?? "",
            startDate: investment?.startDate ?? .now,
            maturityDate: hasMaturityDate ? maturityDate : nil,
            remindsOnMaturity: hasMaturityDate && remindsOnMaturity,
            note: note.isEmpty ? nil : note,
            createdAt: investment?.createdAt ?? .now
        )
    }
}
