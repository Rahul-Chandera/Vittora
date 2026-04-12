import Foundation

@Observable @MainActor final class TransactionFilterViewModel {
    var startDate: Date?
    var endDate: Date?
    var selectedTypes: Set<TransactionType> = []
    var selectedCategoryIDs: Set<UUID> = []
    var selectedAccountIDs: Set<UUID> = []
    var selectedPayeeIDs: Set<UUID> = []
    var amountMin: String = ""
    var amountMax: String = ""
    var selectedTags: Set<String> = []
    var datePreset: DatePreset = .allTime

    enum DatePreset: String, CaseIterable {
        case allTime = "All Time"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case custom = "Custom"

        var displayName: String {
            self.rawValue
        }
    }

    var hasActiveFilters: Bool {
        startDate != nil ||
        endDate != nil ||
        !selectedTypes.isEmpty ||
        !selectedCategoryIDs.isEmpty ||
        !selectedAccountIDs.isEmpty ||
        !selectedPayeeIDs.isEmpty ||
        !amountMin.isEmpty ||
        !amountMax.isEmpty ||
        !selectedTags.isEmpty ||
        datePreset != .allTime
    }

    func buildFilter() -> TransactionFilter {
        var dateRange: ClosedRange<Date>?
        if let start = startDate, let end = endDate {
            dateRange = start...end
        }

        let amountRange: ClosedRange<Decimal>?
        if let minStr = amountMin.isEmpty ? nil : amountMin,
           let maxStr = amountMax.isEmpty ? nil : amountMax,
           let min = Decimal(string: minStr),
           let max = Decimal(string: maxStr) {
            amountRange = min...max
        } else if let minStr = amountMin.isEmpty ? nil : amountMin,
                  let min = Decimal(string: minStr) {
            amountRange = min...Decimal(999999)
        } else if let maxStr = amountMax.isEmpty ? nil : amountMax,
                  let max = Decimal(string: maxStr) {
            amountRange = Decimal(0)...max
        } else {
            amountRange = nil
        }

        return TransactionFilter(
            dateRange: dateRange,
            types: selectedTypes.isEmpty ? nil : selectedTypes,
            categoryIDs: selectedCategoryIDs.isEmpty ? nil : selectedCategoryIDs,
            accountIDs: selectedAccountIDs.isEmpty ? nil : selectedAccountIDs,
            payeeIDs: selectedPayeeIDs.isEmpty ? nil : selectedPayeeIDs,
            amountRange: amountRange,
            tags: selectedTags.isEmpty ? nil : selectedTags
        )
    }

    func clearAll() {
        startDate = nil
        endDate = nil
        selectedTypes = []
        selectedCategoryIDs = []
        selectedAccountIDs = []
        selectedPayeeIDs = []
        amountMin = ""
        amountMax = ""
        selectedTags = []
        datePreset = .allTime
    }

    func applyDatePreset(_ preset: DatePreset) {
        datePreset = preset
        let now = Date.now
        let calendar = Calendar.current

        switch preset {
        case .allTime:
            startDate = nil
            endDate = nil

        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start).map {
                calendar.date(byAdding: .second, value: -1, to: $0)
            } ?? now
            startDate = start
            endDate = end

        case .thisWeek:
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            components.weekday = 1
            let start = calendar.date(from: components) ?? now
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? now
            startDate = start
            endDate = end

        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start)
                .map { calendar.date(byAdding: .second, value: -1, to: $0) } ?? now
            startDate = start
            endDate = end

        case .custom:
            // User will set dates manually
            break
        }
    }
}
