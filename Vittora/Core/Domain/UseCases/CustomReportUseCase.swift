import Foundation

enum ReportGrouping: String, CaseIterable, Sendable, Hashable {
    case category, account, payee, period

    var displayName: String {
        switch self {
        case .category: return String(localized: "Category")
        case .account: return String(localized: "Account")
        case .payee: return String(localized: "Payee")
        case .period: return String(localized: "Month")
        }
    }
}

struct CustomReportRow: Sendable, Identifiable {
    let id = UUID()
    let label: String
    let amount: Decimal
    let count: Int
    let percentage: Double
}

struct CustomReportResult: Sendable {
    let dateRange: ClosedRange<Date>?
    let grouping: ReportGrouping
    let transactionType: TransactionType?
    let rows: [CustomReportRow]
    let total: Decimal
}

struct CustomReportUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let categoryRepository: any CategoryRepository
    let accountRepository: any AccountRepository
    let payeeRepository: any PayeeRepository

    func execute(
        dateRange: ClosedRange<Date>? = nil,
        grouping: ReportGrouping = .category,
        transactionType: TransactionType? = .expense
    ) async throws -> CustomReportResult {
        let filter: TransactionFilter
        if let type = transactionType {
            filter = TransactionFilter(dateRange: dateRange, types: Set([type]))
        } else {
            filter = TransactionFilter(dateRange: dateRange)
        }

        let transactions = try await transactionRepository.fetchAll(filter: filter)

        var groups: [String: (amount: Decimal, count: Int)] = [:]

        switch grouping {
        case .category:
            let categories = try await categoryRepository.fetchAll()
            for t in transactions {
                let name = t.categoryID
                    .flatMap { id in categories.first(where: { $0.id == id })?.name }
                    ?? String(localized: "Uncategorized")
                var entry = groups[name] ?? (amount: Decimal(0), count: 0)
                entry.amount += t.amount
                entry.count += 1
                groups[name] = entry
            }

        case .account:
            let accounts = try await accountRepository.fetchAll()
            for t in transactions {
                let name = t.accountID
                    .flatMap { id in accounts.first(where: { $0.id == id })?.name }
                    ?? String(localized: "Unknown Account")
                var entry = groups[name] ?? (amount: Decimal(0), count: 0)
                entry.amount += t.amount
                entry.count += 1
                groups[name] = entry
            }

        case .payee:
            let payees = try await payeeRepository.fetchAll()
            for t in transactions {
                let name = t.payeeID
                    .flatMap { id in payees.first(where: { $0.id == id })?.name }
                    ?? String(localized: "Unknown Payee")
                var entry = groups[name] ?? (amount: Decimal(0), count: 0)
                entry.amount += t.amount
                entry.count += 1
                groups[name] = entry
            }

        case .period:
            let calendar = Calendar.current
            for t in transactions {
                let components = calendar.dateComponents([.year, .month], from: t.date)
                let label = calendar.date(from: components)
                    .map { $0.formatted(.dateTime.year().month(.wide)) }
                    ?? String(localized: "Unknown")
                var entry = groups[label] ?? (amount: Decimal(0), count: 0)
                entry.amount += t.amount
                entry.count += 1
                groups[label] = entry
            }
        }

        let total = groups.values.reduce(Decimal(0)) { $0 + $1.amount }

        let rows = groups
            .map { (label, data) -> CustomReportRow in
                let percentage = total > 0
                    ? Double(truncating: (data.amount / total * 100) as NSDecimalNumber)
                    : 0.0
                return CustomReportRow(
                    label: label,
                    amount: data.amount,
                    count: data.count,
                    percentage: percentage
                )
            }
            .sorted { $0.amount > $1.amount }

        return CustomReportResult(
            dateRange: dateRange,
            grouping: grouping,
            transactionType: transactionType,
            rows: rows,
            total: total
        )
    }
}
