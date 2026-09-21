import SwiftUI
import VittoraCore

/// The maturity timeline for tracked tax-saving investments (M2.4.5).
struct InvestmentTimelineView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode

    @State private var investments: [Investment] = []
    @State private var editing: Investment?
    @State private var isAdding = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if investments.isEmpty {
                    VEmptyState(
                        icon: "calendar.badge.clock",
                        title: String(localized: "Nothing tracked yet"),
                        subtitle: String(localized: "Add an investment to see when its lock-in ends and get a reminder before it matures."),
                        actionLabel: String(localized: "Add Investment"),
                        action: { isAdding = true }
                    )
                } else {
                    list
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VColors.groupedBackground)
            .navigationTitle(String(localized: "Maturity Timeline"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                        .accessibilityIdentifier("investment-timeline-done-button")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "Add investment"))
                    .accessibilityIdentifier("investment-add-button")
                }
            }
            .sheet(isPresented: $isAdding) {
                InvestmentFormView(investment: nil) { saved in
                    await save(saved)
                }
            }
            .sheet(item: $editing) { record in
                InvestmentFormView(investment: record) { saved in
                    await save(saved)
                }
            }
            .alert(String(localized: "Error"), isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button(String(localized: "OK")) { error = nil }
            } message: {
                Text(error ?? "")
            }
            .task { await load() }
        }
    }

    private var list: some View {
        List {
            ForEach(investments) { record in
                Button {
                    editing = record
                } label: {
                    row(record)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("investment-row-\(record.id.uuidString)")
            }
            .onDelete { offsets in
                Task { await delete(at: offsets) }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    private func row(_ record: Investment) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            HStack {
                Text(record.name)
                    .font(VTypography.bodyBold)
                    .foregroundStyle(VColors.textPrimary)
                Spacer()
                Text(record.amount.formatted(.currency(code: currencyCode)))
                    .font(VTypography.bodyBold)
                    .amountScaling()
                    .foregroundStyle(VColors.textPrimary)
            }
            Text(maturityLabel(record))
                .font(VTypography.caption1)
                .foregroundStyle(record.hasMatured() ? VColors.income : VColors.textSecondary)
        }
        .frame(minHeight: 44)
        .contentShape([.interaction, .accessibility], Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Reads the same way whether the date is ahead, today, past, or absent — an
    /// age-linked lock-in has no countdown to show and must not render as "0 days".
    private func maturityLabel(_ record: Investment) -> String {
        guard let maturityDate = record.maturityDate, let days = record.daysToMaturity() else {
            return String(localized: "Matures when you turn 60")
        }
        let formatted = maturityDate.formatted(date: .abbreviated, time: .omitted)
        if days > 0 {
            return String(localized: "Matures \(formatted) · \(days) days away")
        }
        if days == 0 {
            return String(localized: "Matures today · \(formatted)")
        }
        return String(localized: "Matured \(formatted)")
    }

    private func load() async {
        do {
            investments = try await dependencies.investmentRepository.fetchAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save(_ record: Investment) async {
        do {
            try await dependencies.investmentRepository.save(record)
            await load()
            // Reconcile immediately: an edit that clears the date or switches the reminder
            // off has to cancel the pending notification, not wait for the next launch.
            await dependencies.refreshInvestmentMaturityReminders()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) async {
        do {
            for index in offsets {
                try await dependencies.investmentRepository.delete(id: investments[index].id)
            }
            await load()
            await dependencies.refreshInvestmentMaturityReminders()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
