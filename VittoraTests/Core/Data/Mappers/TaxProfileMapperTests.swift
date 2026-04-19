import Foundation
import Testing
import SwiftData

@testable import Vittora

@Suite("TaxProfileMapper Tests")
struct TaxProfileMapperTests {

    @Test("toEntity maps all fields correctly")
    func testToEntityMapsAllFields() {
        let id = UUID()
        let country = TaxCountry.india
        let annualIncome = Decimal(1_200_000)
        let indiaRegime = IndiaRegime.oldRegime
        let filingStatus = USFilingStatus.marriedFilingJointly
        let deduction = TaxDeduction(name: "80C Investment", amount: Decimal(150_000), section: "80C")
        let customDeductions = [deduction]
        let financialYear = "2025-26"
        let incomeSourceType = IncomeSourceType.salaried
        let dateOfBirth = Date(timeIntervalSince1970: 0)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)

        let model = SDTaxProfile(
            id: id,
            country: country,
            annualIncome: annualIncome,
            indiaRegime: indiaRegime,
            filingStatus: filingStatus,
            customDeductions: customDeductions,
            financialYear: financialYear,
            incomeSourceType: incomeSourceType,
            dateOfBirth: dateOfBirth,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = TaxProfileMapper.toEntity(model)

        #expect(entity.id == id)
        #expect(entity.country == country)
        #expect(entity.annualIncome == annualIncome)
        #expect(entity.indiaRegime == indiaRegime)
        #expect(entity.filingStatus == filingStatus)
        #expect(entity.customDeductions.count == 1)
        #expect(entity.customDeductions.first?.name == "80C Investment")
        #expect(entity.customDeductions.first?.amount == Decimal(150_000))
        #expect(entity.customDeductions.first?.section == "80C")
        #expect(entity.financialYear == financialYear)
        #expect(entity.incomeSourceType == incomeSourceType)
        #expect(entity.dateOfBirth == dateOfBirth)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("toEntity maps nil dateOfBirth and empty deductions correctly")
    func testToEntityMapsNilAndEmptyFields() {
        let model = SDTaxProfile(
            country: .unitedStates,
            annualIncome: Decimal(75_000),
            indiaRegime: .newRegime,
            filingStatus: .single,
            customDeductions: [],
            financialYear: "2026"
        )

        let entity = TaxProfileMapper.toEntity(model)

        #expect(entity.dateOfBirth == nil)
        #expect(entity.customDeductions.isEmpty)
    }

    @Test("updateModel modifies mutable fields and stamps updatedAt")
    func testUpdateModelModifiesMutableFields() {
        let model = SDTaxProfile()
        let originalID = model.id
        let originalCreatedAt = model.createdAt

        let dateOfBirth = Date(timeIntervalSince1970: -315_619_200)
        let deduction = TaxDeduction(name: "HRA", amount: Decimal(120_000), section: "HRA")
        let entity = TaxProfile(
            country: .unitedStates,
            annualIncome: Decimal(90_000),
            indiaRegime: .newRegime,
            filingStatus: .headOfHousehold,
            customDeductions: [deduction],
            financialYear: "2026",
            incomeSourceType: .selfEmployed,
            dateOfBirth: dateOfBirth
        )

        TaxProfileMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.country == .unitedStates)
        #expect(model.annualIncome == Decimal(90_000))
        #expect(model.indiaRegime == .newRegime)
        #expect(model.filingStatus == .headOfHousehold)
        #expect(model.customDeductions.count == 1)
        #expect(model.customDeductions.first?.name == "HRA")
        #expect(model.financialYear == "2026")
        #expect(model.incomeSourceType == .selfEmployed)
        #expect(model.dateOfBirth == dateOfBirth)
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("Round-trip mapping preserves all fields")
    func testRoundTripMapping() {
        let id = UUID()
        let dateOfBirth = Date(timeIntervalSince1970: -157_766_400)
        let deduction1 = TaxDeduction(name: "80C", amount: Decimal(150_000), section: "80C")
        let deduction2 = TaxDeduction(name: "80D", amount: Decimal(25_000), section: "80D")
        let createdAt = Date(timeIntervalSince1970: 1_695_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_695_001_000)

        let model = SDTaxProfile(
            id: id,
            country: .india,
            annualIncome: Decimal(2_000_000),
            indiaRegime: .oldRegime,
            filingStatus: .single,
            customDeductions: [deduction1, deduction2],
            financialYear: "2025-26",
            incomeSourceType: .salaried,
            dateOfBirth: dateOfBirth,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = TaxProfileMapper.toEntity(model)
        TaxProfileMapper.updateModel(model, from: entity)

        #expect(model.id == id)
        #expect(model.country == .india)
        #expect(model.annualIncome == Decimal(2_000_000))
        #expect(model.indiaRegime == .oldRegime)
        #expect(model.filingStatus == .single)
        #expect(model.customDeductions.count == 2)
        #expect(model.financialYear == "2025-26")
        #expect(model.incomeSourceType == .salaried)
        #expect(model.dateOfBirth == dateOfBirth)
        #expect(model.createdAt == createdAt)
    }

    @Test("toEntity with all India regimes")
    func testToEntityWithAllIndiaRegimes() {
        let regimes: [IndiaRegime] = [.newRegime, .oldRegime]

        for regime in regimes {
            let model = SDTaxProfile(
                country: .india,
                annualIncome: Decimal(500_000),
                indiaRegime: regime,
                filingStatus: .single,
                financialYear: "2025-26"
            )
            let entity = TaxProfileMapper.toEntity(model)
            #expect(entity.indiaRegime == regime)
        }
    }

    @Test("toEntity with all US filing statuses")
    func testToEntityWithAllUSFilingStatuses() {
        let statuses: [USFilingStatus] = [
            .single,
            .marriedFilingJointly,
            .marriedFilingSeparately,
            .headOfHousehold,
            .qualifyingSurvivingSpouse
        ]

        for status in statuses {
            let model = SDTaxProfile(
                country: .unitedStates,
                annualIncome: Decimal(80_000),
                indiaRegime: .newRegime,
                filingStatus: status,
                financialYear: "2026"
            )
            let entity = TaxProfileMapper.toEntity(model)
            #expect(entity.filingStatus == status)
        }
    }

    @Test("toEntity with all income source types")
    func testToEntityWithAllIncomeSourceTypes() {
        let types: [IncomeSourceType] = [.salaried, .selfEmployed]

        for incomeType in types {
            let model = SDTaxProfile(
                country: .india,
                annualIncome: Decimal(600_000),
                indiaRegime: .newRegime,
                filingStatus: .single,
                financialYear: "2025-26",
                incomeSourceType: incomeType
            )
            let entity = TaxProfileMapper.toEntity(model)
            #expect(entity.incomeSourceType == incomeType)
        }
    }
}
