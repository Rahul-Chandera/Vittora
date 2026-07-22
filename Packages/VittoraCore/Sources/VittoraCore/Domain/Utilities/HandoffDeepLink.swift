import Foundation

/// Continuity / Handoff routes expressed as `vittora://` URLs so continuation
/// reuses the same `AppState.openFromURL` path as widgets and Spotlight.
///
/// Privacy: `userInfo` carries identifiers and draft field values only — never
/// balances, spent totals, or other aggregates.
public enum HandoffDeepLink: Sendable {
    public static let scheme = "vittora"

    public enum Host: String, Sendable {
        case transactions
        case transaction
        case budget
        case account
        case report
        case add
    }

    /// Unsaved transaction form fields (string amount — never float Decimal literals).
    public struct Draft: Sendable, Equatable, Hashable {
        public var amount: String?
        public var note: String?
        public var categoryID: UUID?
        public var accountID: UUID?
        public var date: Date?
        public var type: String?

        public nonisolated init(
            amount: String? = nil,
            note: String? = nil,
            categoryID: UUID? = nil,
            accountID: UUID? = nil,
            date: Date? = nil,
            type: String? = nil
        ) {
            self.amount = amount
            self.note = note
            self.categoryID = categoryID
            self.accountID = accountID
            self.date = date
            self.type = type
        }
    }

    /// Date-range + id filters for the transaction list (identifiers only).
    public struct ListFilter: Sendable, Equatable, Hashable {
        public var start: Date?
        public var end: Date?
        public var types: [String]?
        public var categoryIDs: [UUID]?
        public var accountIDs: [UUID]?

        public nonisolated init(
            start: Date? = nil,
            end: Date? = nil,
            types: [String]? = nil,
            categoryIDs: [UUID]? = nil,
            accountIDs: [UUID]? = nil
        ) {
            self.start = start
            self.end = end
            self.types = types
            self.categoryIDs = categoryIDs
            self.accountIDs = accountIDs
        }

        public var dateRange: ClosedRange<Date>? {
            guard let start, let end, start <= end else { return nil }
            return start...end
        }
    }

    public enum Route: Sendable, Equatable, Hashable {
        case transactionList(ListFilter)
        case transactionDetail(UUID)
        /// Budgets tab root (used when a continued budget ID is missing).
        case budgetsList
        case budgetDetail(UUID)
        /// Accounts entry (dashboard) when a continued account ID is missing.
        case accountsList
        case accountDetail(UUID)
        case reportDetail(type: String, start: Date?, end: Date?)
        case transactionDraft(Draft)
    }

    // MARK: - Keys (userInfo / query)

    public static let kindKey = "kind"
    public static let idKey = "id"
    public static let startKey = "start"
    public static let endKey = "end"
    public static let typesKey = "types"
    public static let categoryIDsKey = "categoryIDs"
    public static let accountIDsKey = "accountIDs"
    public static let reportTypeKey = "reportType"
    public static let amountKey = "amount"
    public static let noteKey = "note"
    public static let categoryIDKey = "categoryID"
    public static let accountIDKey = "accountID"
    public static let dateKey = "date"
    public static let typeKey = "type"

    /// Known-safe keys permitted in a Handoff payload (identifiers / draft fields only).
    /// Anything else is a leak by definition — fail closed.
    public static let allowedUserInfoKeys: Set<String> = [
        kindKey,
        idKey,
        startKey,
        endKey,
        typesKey,
        categoryIDsKey,
        accountIDsKey,
        reportTypeKey,
        amountKey,
        noteKey,
        categoryIDKey,
        accountIDKey,
        dateKey,
        typeKey,
    ]

    // MARK: - URL

    public static func url(for route: Route) -> URL {
        switch route {
        case .transactionList(let filter):
            return makeURL(host: .transactions, path: nil, query: listFilterQuery(filter))
        case .transactionDetail(let id):
            return makeURL(host: .transaction, path: "/\(id.uuidString)", query: [])
        case .budgetsList:
            return makeURL(host: .budget, path: nil, query: [])
        case .budgetDetail(let id):
            return makeURL(host: .budget, path: "/\(id.uuidString)", query: [])
        case .accountsList:
            return makeURL(host: .account, path: nil, query: [])
        case .accountDetail(let id):
            return makeURL(host: .account, path: "/\(id.uuidString)", query: [])
        case .reportDetail(let type, let start, let end):
            var items = [URLQueryItem(name: reportTypeKey, value: type)]
            if let start { items.append(URLQueryItem(name: startKey, value: iso8601(start))) }
            if let end { items.append(URLQueryItem(name: endKey, value: iso8601(end))) }
            return makeURL(host: .report, path: "/\(type)", query: items)
        case .transactionDraft(let draft):
            return makeURL(host: .add, path: nil, query: draftQuery(draft))
        }
    }

    public static func isHandoffURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == scheme,
              let host = url.host?.lowercased(),
              Host(rawValue: host) != nil
        else {
            return false
        }
        return true
    }

    public static func route(from url: URL) -> Route? {
        guard url.scheme?.lowercased() == scheme,
              let hostRaw = url.host?.lowercased(),
              let host = Host(rawValue: hostRaw)
        else {
            return nil
        }

        let pathID = uuidFromPath(url.path)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        switch host {
        case .transactions:
            return .transactionList(listFilter(from: items))
        case .transaction:
            guard let pathID else { return nil }
            return .transactionDetail(pathID)
        case .budget:
            if let pathID { return .budgetDetail(pathID) }
            return .budgetsList
        case .account:
            if let pathID { return .accountDetail(pathID) }
            return .accountsList
        case .report:
            let type = pathSegment(url.path)
                ?? items.first(where: { $0.name == reportTypeKey })?.value
            guard let type, !type.isEmpty else { return nil }
            return .reportDetail(
                type: type,
                start: dateValue(items, key: startKey),
                end: dateValue(items, key: endKey)
            )
        case .add:
            return .transactionDraft(draft(from: items))
        }
    }

    // MARK: - userInfo

    public static func userInfo(for route: Route) -> [String: Any] {
        switch route {
        case .transactionList(let filter):
            var info: [String: Any] = [kindKey: Host.transactions.rawValue]
            if let start = filter.start { info[startKey] = iso8601(start) }
            if let end = filter.end { info[endKey] = iso8601(end) }
            if let types = filter.types, !types.isEmpty {
                info[typesKey] = types.joined(separator: ",")
            }
            if let ids = filter.categoryIDs, !ids.isEmpty {
                info[categoryIDsKey] = ids.map(\.uuidString).sorted().joined(separator: ",")
            }
            if let ids = filter.accountIDs, !ids.isEmpty {
                info[accountIDsKey] = ids.map(\.uuidString).sorted().joined(separator: ",")
            }
            return info
        case .transactionDetail(let id):
            return [kindKey: Host.transaction.rawValue, idKey: id.uuidString]
        case .budgetsList:
            return [kindKey: Host.budget.rawValue]
        case .budgetDetail(let id):
            return [kindKey: Host.budget.rawValue, idKey: id.uuidString]
        case .accountsList:
            return [kindKey: Host.account.rawValue]
        case .accountDetail(let id):
            return [kindKey: Host.account.rawValue, idKey: id.uuidString]
        case .reportDetail(let type, let start, let end):
            var info: [String: Any] = [
                kindKey: Host.report.rawValue,
                reportTypeKey: type,
            ]
            if let start { info[startKey] = iso8601(start) }
            if let end { info[endKey] = iso8601(end) }
            return info
        case .transactionDraft(let draft):
            var info: [String: Any] = [kindKey: Host.add.rawValue]
            if let amount = draft.amount { info[amountKey] = amount }
            if let note = draft.note { info[noteKey] = note }
            if let categoryID = draft.categoryID { info[categoryIDKey] = categoryID.uuidString }
            if let accountID = draft.accountID { info[accountIDKey] = accountID.uuidString }
            if let date = draft.date { info[dateKey] = iso8601(date) }
            if let type = draft.type { info[typeKey] = type }
            return info
        }
    }

    public static func requiredUserInfoKeys(for route: Route) -> Set<String> {
        switch route {
        case .transactionList, .budgetsList, .accountsList, .transactionDraft:
            [kindKey]
        case .transactionDetail, .budgetDetail, .accountDetail:
            [kindKey, idKey]
        case .reportDetail:
            [kindKey, reportTypeKey]
        }
    }

    public static func route(fromUserInfo userInfo: [AnyHashable: Any]?) -> Route? {
        guard let userInfo,
              let kind = userInfo[kindKey] as? String
        else {
            return nil
        }

        switch kind {
        case Host.transactions.rawValue:
            return .transactionList(listFilter(fromUserInfo: userInfo))
        case Host.transaction.rawValue:
            guard let id = uuidValue(userInfo[idKey]) else { return nil }
            return .transactionDetail(id)
        case Host.budget.rawValue:
            if let id = uuidValue(userInfo[idKey]) { return .budgetDetail(id) }
            return .budgetsList
        case Host.account.rawValue:
            if let id = uuidValue(userInfo[idKey]) { return .accountDetail(id) }
            return .accountsList
        case Host.report.rawValue:
            guard let type = userInfo[reportTypeKey] as? String, !type.isEmpty else { return nil }
            return .reportDetail(
                type: type,
                start: dateValue(userInfo[startKey]),
                end: dateValue(userInfo[endKey])
            )
        case Host.add.rawValue:
            return .transactionDraft(draft(fromUserInfo: userInfo))
        default:
            return nil
        }
    }

    /// `true` when `userInfo` contains any key outside the allowlist.
    public static func userInfoContainsForbiddenKeys(_ userInfo: [AnyHashable: Any]?) -> Bool {
        guard let userInfo else { return false }
        for key in userInfo.keys {
            let raw = String(describing: key)
            if !allowedUserInfoKeys.contains(raw) {
                return true
            }
        }
        return false
    }

    // MARK: - Resolution

    /// When a continued entity ID is gone, fall back to the list — never crash.
    public static func resolve(
        _ route: Route,
        transactionExists: (UUID) -> Bool = { _ in true },
        budgetExists: (UUID) -> Bool = { _ in true },
        accountExists: (UUID) -> Bool = { _ in true }
    ) -> Route {
        switch route {
        case .transactionDetail(let id) where !transactionExists(id):
            return .transactionList(ListFilter())
        case .budgetDetail(let id) where !budgetExists(id):
            return .budgetsList
        case .accountDetail(let id) where !accountExists(id):
            return .accountsList
        default:
            return route
        }
    }
}

// MARK: - Private helpers

private extension HandoffDeepLink {
    static func makeURL(host: Host, path: String?, query: [URLQueryItem]) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host.rawValue
        if let path, !path.isEmpty {
            components.path = path.hasPrefix("/") ? path : "/\(path)"
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        return components.url ?? URL(fileURLWithPath: "/invalid-handoff-link")
    }

    static func listFilterQuery(_ filter: ListFilter) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let start = filter.start { items.append(URLQueryItem(name: startKey, value: iso8601(start))) }
        if let end = filter.end { items.append(URLQueryItem(name: endKey, value: iso8601(end))) }
        if let types = filter.types, !types.isEmpty {
            items.append(URLQueryItem(name: typesKey, value: types.joined(separator: ",")))
        }
        if let ids = filter.categoryIDs, !ids.isEmpty {
            items.append(URLQueryItem(name: categoryIDsKey, value: ids.map(\.uuidString).sorted().joined(separator: ",")))
        }
        if let ids = filter.accountIDs, !ids.isEmpty {
            items.append(URLQueryItem(name: accountIDsKey, value: ids.map(\.uuidString).sorted().joined(separator: ",")))
        }
        return items
    }

    static func draftQuery(_ draft: Draft) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        let type = draft.type ?? QuickAddDeepLink.Destination.expense.rawValue
        items.append(URLQueryItem(name: typeKey, value: type))
        if let amount = draft.amount { items.append(URLQueryItem(name: amountKey, value: amount)) }
        if let note = draft.note { items.append(URLQueryItem(name: noteKey, value: note)) }
        if let categoryID = draft.categoryID {
            items.append(URLQueryItem(name: categoryIDKey, value: categoryID.uuidString))
        }
        if let accountID = draft.accountID {
            items.append(URLQueryItem(name: accountIDKey, value: accountID.uuidString))
        }
        if let date = draft.date { items.append(URLQueryItem(name: dateKey, value: iso8601(date))) }
        return items
    }

    static func listFilter(from items: [URLQueryItem]) -> ListFilter {
        ListFilter(
            start: dateValue(items, key: startKey),
            end: dateValue(items, key: endKey),
            types: csvStrings(items.first(where: { $0.name == typesKey })?.value),
            categoryIDs: csvUUIDs(items.first(where: { $0.name == categoryIDsKey })?.value),
            accountIDs: csvUUIDs(items.first(where: { $0.name == accountIDsKey })?.value)
        )
    }

    static func listFilter(fromUserInfo userInfo: [AnyHashable: Any]) -> ListFilter {
        ListFilter(
            start: dateValue(userInfo[startKey]),
            end: dateValue(userInfo[endKey]),
            types: csvStrings(userInfo[typesKey] as? String),
            categoryIDs: csvUUIDs(userInfo[categoryIDsKey] as? String),
            accountIDs: csvUUIDs(userInfo[accountIDsKey] as? String)
        )
    }

    static func draft(from items: [URLQueryItem]) -> Draft {
        Draft(
            amount: items.first(where: { $0.name == amountKey })?.value,
            note: items.first(where: { $0.name == noteKey })?.value,
            categoryID: uuidValue(items.first(where: { $0.name == categoryIDKey })?.value),
            accountID: uuidValue(items.first(where: { $0.name == accountIDKey })?.value),
            date: dateValue(items, key: dateKey),
            type: items.first(where: { $0.name == typeKey })?.value?.lowercased()
        )
    }

    static func draft(fromUserInfo userInfo: [AnyHashable: Any]) -> Draft {
        Draft(
            amount: userInfo[amountKey] as? String,
            note: userInfo[noteKey] as? String,
            categoryID: uuidValue(userInfo[categoryIDKey]),
            accountID: uuidValue(userInfo[accountIDKey]),
            date: dateValue(userInfo[dateKey]),
            type: (userInfo[typeKey] as? String)?.lowercased()
        )
    }

    static func uuidFromPath(_ path: String) -> UUID? {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return nil }
        return UUID(uuidString: trimmed)
    }

    static func pathSegment(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? nil : trimmed
    }

    static func uuidValue(_ value: Any?) -> UUID? {
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String { return UUID(uuidString: string) }
        return nil
    }

    static func dateValue(_ items: [URLQueryItem], key: String) -> Date? {
        dateValue(items.first(where: { $0.name == key })?.value)
    }

    static func dateValue(_ value: Any?) -> Date? {
        if let date = value as? Date { return date }
        if let string = value as? String { return parseISO8601(string) }
        if let interval = value as? TimeInterval { return Date(timeIntervalSince1970: interval) }
        return nil
    }

    static func csvStrings(_ value: String?) -> [String]? {
        guard let value, !value.isEmpty else { return nil }
        let parts = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts
    }

    static func csvUUIDs(_ value: String?) -> [UUID]? {
        guard let strings = csvStrings(value) else { return nil }
        let ids = strings.compactMap(UUID.init(uuidString:)).sorted { $0.uuidString < $1.uuidString }
        return ids.isEmpty ? nil : ids
    }

    static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
