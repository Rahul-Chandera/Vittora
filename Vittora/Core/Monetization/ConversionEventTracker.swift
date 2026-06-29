import Foundation

protocol ConversionEventTracking: Sendable {
    func record(_ milestone: ConversionMilestone) -> ConversionEventResult
    func shouldPresentPaywall(for milestone: ConversionMilestone) -> Bool
    func markPaywallPresented(for milestone: ConversionMilestone)
    func hasRecorded(_ milestone: ConversionMilestone) -> Bool
    func recordOCRScan() -> ConversionEventResult
    func ocrScansThisMonth() -> Int
}

final class UserDefaultsConversionEventTracker: ConversionEventTracking, @unchecked Sendable {
    private nonisolated(unsafe) let defaults: UserDefaults
    private nonisolated let calendar: Calendar
    private nonisolated let nowProvider: @Sendable () -> Date
    private nonisolated let lock = NSLock()

    private enum Keys {
        nonisolated static let prefix = "vittora.conversion."
        nonisolated static let lastPaywallPresented = prefix + "lastPaywallPresented"
        nonisolated static let ocrMonthBucket = prefix + "ocrMonthBucket"
        nonisolated static let ocrMonthCount = prefix + "ocrMonthCount"

        nonisolated static func milestone(_ milestone: ConversionMilestone) -> String {
            prefix + "milestone." + milestone.rawValue
        }
    }

    nonisolated init(
        defaults: UserDefaults = AppUserDefaults.conversion,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = { Date.now }
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    nonisolated func record(_ milestone: ConversionMilestone) -> ConversionEventResult {
        lock.lock()
        defer { lock.unlock() }

        let key = Keys.milestone(milestone)
        let isFirstTime = !defaults.bool(forKey: key)
        if isFirstTime {
            defaults.set(true, forKey: key)
        }

        let shouldPresent = evaluatePaywallPresentation(
            milestone: milestone,
            isFirstTime: isFirstTime
        )
        return ConversionEventResult(
            milestone: milestone,
            isFirstTime: isFirstTime,
            shouldPresentPaywall: shouldPresent
        )
    }

    nonisolated func shouldPresentPaywall(for milestone: ConversionMilestone) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let isFirstTime = defaults.bool(forKey: Keys.milestone(milestone))
        return evaluatePaywallPresentation(milestone: milestone, isFirstTime: isFirstTime)
    }

    nonisolated func markPaywallPresented(for milestone: ConversionMilestone) {
        lock.lock()
        defer { lock.unlock() }
        defaults.set(nowProvider(), forKey: Keys.lastPaywallPresented)
    }

    nonisolated func hasRecorded(_ milestone: ConversionMilestone) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return defaults.bool(forKey: Keys.milestone(milestone))
    }

    nonisolated func recordOCRScan() -> ConversionEventResult {
        lock.lock()
        incrementOCRCountLocked()
        lock.unlock()

        let firstScan = record(.firstOCRScan)
        if ocrScansThisMonth() >= FreeTierLimits.maxOCRScansPerMonth,
           !hasRecorded(.ocrMonthlyLimitReached) {
            return record(.ocrMonthlyLimitReached)
        }
        return firstScan
    }

    nonisolated func ocrScansThisMonth() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return currentOCRCountLocked()
    }

    nonisolated private func evaluatePaywallPresentation(
        milestone: ConversionMilestone,
        isFirstTime: Bool
    ) -> Bool {
        guard MonetizationConfiguration.isStoreKitEnabled else { return false }
        guard isFirstTime else { return false }

        if let lastPresented = defaults.object(forKey: Keys.lastPaywallPresented) as? Date {
            let cooldown = TimeInterval(MonetizationConfiguration.paywallPresentationCooldownDays * 24 * 60 * 60)
            if nowProvider().timeIntervalSince(lastPresented) < cooldown {
                return false
            }
        }
        return true
    }

    nonisolated private func incrementOCRCountLocked() {
        let bucket = monthBucket(for: nowProvider())
        let storedBucket = defaults.string(forKey: Keys.ocrMonthBucket)
        if storedBucket != bucket {
            defaults.set(bucket, forKey: Keys.ocrMonthBucket)
            defaults.set(1, forKey: Keys.ocrMonthCount)
        } else {
            let count = defaults.integer(forKey: Keys.ocrMonthCount)
            defaults.set(count + 1, forKey: Keys.ocrMonthCount)
        }
    }

    nonisolated private func currentOCRCountLocked() -> Int {
        let bucket = monthBucket(for: nowProvider())
        guard defaults.string(forKey: Keys.ocrMonthBucket) == bucket else { return 0 }
        return defaults.integer(forKey: Keys.ocrMonthCount)
    }

    nonisolated private func monthBucket(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "%04d-%02d", year, month)
    }
}
