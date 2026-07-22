import Foundation

/// Counts-only snapshot for the user-reviewed support diagnostics payload.
/// Never include amounts, notes, payees, account/category names, or persistent IDs.
public struct DiagnosticSnapshot: Sendable, Equatable {
    public var appVersion: String
    public var buildNumber: String
    public var osName: String
    public var osVersion: String
    public var deviceModel: String
    public var localeIdentifier: String
    public var currencyCode: String
    public var cloudSyncEnabled: Bool
    public var lastSyncResult: String
    public var transactionCount: Int
    public var accountCount: Int
    public var categoryCount: Int
    public var budgetCount: Int
    public var debtCount: Int
    public var savingsGoalCount: Int
    public var splitGroupCount: Int
    public var documentCount: Int
    public var payeeCount: Int
    public var recurringRuleCount: Int
    public var recentErrors: [RecentErrorEntry]

    public init(
        appVersion: String,
        buildNumber: String,
        osName: String,
        osVersion: String,
        deviceModel: String,
        localeIdentifier: String,
        currencyCode: String,
        cloudSyncEnabled: Bool,
        lastSyncResult: String,
        transactionCount: Int,
        accountCount: Int,
        categoryCount: Int,
        budgetCount: Int,
        debtCount: Int,
        savingsGoalCount: Int,
        splitGroupCount: Int,
        documentCount: Int,
        payeeCount: Int,
        recurringRuleCount: Int,
        recentErrors: [RecentErrorEntry]
    ) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.osName = osName
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.localeIdentifier = localeIdentifier
        self.currencyCode = currencyCode
        self.cloudSyncEnabled = cloudSyncEnabled
        self.lastSyncResult = lastSyncResult
        self.transactionCount = transactionCount
        self.accountCount = accountCount
        self.categoryCount = categoryCount
        self.budgetCount = budgetCount
        self.debtCount = debtCount
        self.savingsGoalCount = savingsGoalCount
        self.splitGroupCount = splitGroupCount
        self.documentCount = documentCount
        self.payeeCount = payeeCount
        self.recurringRuleCount = recurringRuleCount
        self.recentErrors = recentErrors
    }
}

public enum DiagnosticPayload {
    public static let supportEmail = "support@vittora.app"
    public static let supportURL = URL(string: "https://www.vittora.app/support")!

    /// Renders the exact text the user reviews before sending via their mail composer.
    public static func render(_ snapshot: DiagnosticSnapshot) -> String {
        var lines: [String] = [
            "Vittora Diagnostics",
            "===================",
            "App: \(snapshot.appVersion) (\(snapshot.buildNumber))",
            "OS: \(snapshot.osName) \(snapshot.osVersion)",
            "Device: \(snapshot.deviceModel)",
            "Locale: \(snapshot.localeIdentifier)",
            "Currency: \(snapshot.currencyCode)",
            "iCloud Sync: \(snapshot.cloudSyncEnabled ? "enabled" : "disabled")",
            "Last Sync Result: \(snapshot.lastSyncResult)",
            "",
            "Record Counts",
            "-------------",
            "Transactions: \(snapshot.transactionCount)",
            "Accounts: \(snapshot.accountCount)",
            "Categories: \(snapshot.categoryCount)",
            "Budgets: \(snapshot.budgetCount)",
            "Debts: \(snapshot.debtCount)",
            "Savings Goals: \(snapshot.savingsGoalCount)",
            "Split Groups: \(snapshot.splitGroupCount)",
            "Documents: \(snapshot.documentCount)",
            "Payees: \(snapshot.payeeCount)",
            "Recurring Rules: \(snapshot.recurringRuleCount)",
        ]

        lines.append("")
        lines.append("Recent Errors (last \(RecentErrorLogStore.maxEntries), code path only)")
        lines.append("---------------------------------------------------------")
        if snapshot.recentErrors.isEmpty {
            lines.append("(none)")
        } else {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            for entry in snapshot.recentErrors {
                lines.append(
                    "\(formatter.string(from: entry.recordedAt)) | \(entry.errorType) | \(entry.codePath)"
                )
            }
        }

        return lines.joined(separator: "\n")
    }
}

/// Hardware model + OS version for diagnostics — never a persistent install/device ID.
public enum DiagnosticDeviceInfo {
    public static var osVersionString: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    public static var hardwareModel: String {
        #if os(macOS)
        return sysctlString("hw.model") ?? "Mac"
        #else
        return utsnameMachine() ?? "Unknown"
        #endif
    }

    #if os(macOS)
    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
    #else
    private static func utsnameMachine() -> String? {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { machine in
                let value = String(cString: machine)
                return value.isEmpty ? nil : value
            }
        }
    }
    #endif
}
