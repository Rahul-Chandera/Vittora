import Foundation

public enum InvestmentMapper {
    public nonisolated static func toEntity(_ model: SDInvestment) -> Investment {
        Investment(
            id: model.id,
            name: model.name,
            instrumentID: model.instrumentID,
            amount: model.amount,
            sectionKey: model.sectionKey,
            startDate: model.startDate,
            maturityDate: model.maturityDate,
            remindsOnMaturity: model.remindsOnMaturity,
            note: model.note,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    public nonisolated static func updateModel(_ model: SDInvestment, from entity: Investment) {
        model.name = entity.name
        model.instrumentID = entity.instrumentID
        model.amount = entity.amount
        model.sectionKey = entity.sectionKey
        model.startDate = entity.startDate
        model.maturityDate = entity.maturityDate
        model.remindsOnMaturity = entity.remindsOnMaturity
        model.note = entity.note
        model.updatedAt = .now
    }
}
