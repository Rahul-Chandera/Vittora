import Foundation

// MARK: - Goal Category

public enum GoalCategory: String, Sendable, Hashable, CaseIterable, Codable {
    case emergency
    case travel
    case vehicle
    case home
    case education
    case retirement
    case wedding
    case gadget
    case health
    case other

    public var displayName: String {
        switch self {
        case .emergency:  return String(localized: "Emergency Fund")
        case .travel:     return String(localized: "Travel")
        case .vehicle:    return String(localized: "Vehicle")
        case .home:       return String(localized: "Home")
        case .education:  return String(localized: "Education")
        case .retirement: return String(localized: "Retirement")
        case .wedding:    return String(localized: "Wedding")
        case .gadget:     return String(localized: "Gadget")
        case .health:     return String(localized: "Health")
        case .other:      return String(localized: "Other")
        }
    }

    public var systemImage: String {
        switch self {
        case .emergency:  return "shield.fill"
        case .travel:     return "airplane"
        case .vehicle:    return "car.fill"
        case .home:       return "house.fill"
        case .education:  return "graduationcap.fill"
        case .retirement: return "figure.walk"
        case .wedding:    return "heart.fill"
        case .gadget:     return "laptopcomputer"
        case .health:     return "cross.case.fill"
        case .other:      return "star.fill"
        }
    }
}

// MARK: - Goal Status

public enum GoalStatus: String, Sendable, Hashable, Codable {
    case active
    case achieved
    case paused
    case cancelled

    public var displayName: String {
        switch self {
        case .active:    return String(localized: "Active")
        case .achieved:  return String(localized: "Achieved")
        case .paused:    return String(localized: "Paused")
        case .cancelled: return String(localized: "Cancelled")
        }
    }
}

// MARK: - Savings Goal Entity

public struct SavingsGoalEntity: Identifiable, Hashable, Equatable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var name: String
    public nonisolated var category: GoalCategory
    public nonisolated var targetAmount: Decimal
    public nonisolated var currentAmount: Decimal
    public nonisolated var targetDate: Date?
    public nonisolated var linkedAccountID: UUID?
    public nonisolated var note: String?
    public nonisolated var status: GoalStatus
    public nonisolated var colorHex: String
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date

    // MARK: - Computed

    public var remainingAmount: Decimal { max(0, targetAmount - currentAmount) }

    public var progressFraction: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1.0, (currentAmount as NSDecimalNumber).doubleValue / (targetAmount as NSDecimalNumber).doubleValue)
    }

    public var progressPercent: Double { progressFraction * 100 }

    public var isAchieved: Bool { currentAmount >= targetAmount }

    public var daysRemaining: Int? {
        guard let date = targetDate, status == .active else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: date).day
    }

    public var isOverdue: Bool {
        guard let days = daysRemaining else { return false }
        return days < 0 && !isAchieved
    }

    /// Monthly savings needed to hit the target by the deadline
    public var monthlySavingsNeeded: Decimal? {
        guard let days = daysRemaining, days > 0, remainingAmount > 0 else { return nil }
        let months = Decimal(max(1, days / 30))
        let raw = remainingAmount / months
        var result = Decimal()
        var copy = raw
        NSDecimalRound(&result, &copy, 2, .bankers)
        return result
    }

    public nonisolated init(
        id: UUID = UUID(),
        name: String,
        category: GoalCategory = .other,
        targetAmount: Decimal,
        currentAmount: Decimal = 0,
        targetDate: Date? = nil,
        linkedAccountID: UUID? = nil,
        note: String? = nil,
        status: GoalStatus = .active,
        colorHex: String = "#5856D6",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
        self.linkedAccountID = linkedAccountID
        self.note = note
        self.status = status
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Progress Summary

public struct GoalProgressSummary: Sendable {
    public nonisolated let totalGoals: Int
    public nonisolated let activeGoals: Int
    public nonisolated let achievedGoals: Int
    public nonisolated let totalTargetAmount: Decimal
    public nonisolated let totalSavedAmount: Decimal
    public nonisolated var overallProgressFraction: Double {
        guard totalTargetAmount > 0 else { return 0 }
        return min(1.0, (totalSavedAmount as NSDecimalNumber).doubleValue /
                        (totalTargetAmount as NSDecimalNumber).doubleValue)
    }

    public nonisolated init(
        totalGoals: Int,
        activeGoals: Int,
        achievedGoals: Int,
        totalTargetAmount: Decimal,
        totalSavedAmount: Decimal
    ) {
        self.totalGoals = totalGoals
        self.activeGoals = activeGoals
        self.achievedGoals = achievedGoals
        self.totalTargetAmount = totalTargetAmount
        self.totalSavedAmount = totalSavedAmount
    }
}
