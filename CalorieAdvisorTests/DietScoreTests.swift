import Foundation
import Testing
@testable import CalorieAdvisor

struct DietScoreTests {
    private func hydration(water volume: Double) -> HydrationSummary {
        HydrationSummary(entries: [entry("Eau plate", unit: .milliliter, quantity: volume,
                                         nutrients: .zero, meal: .drinks)])
    }

    @Test func dayBelow300KcalIsNotScored() {
        #expect(DietScore(intake: Nutrients(kcal: 299), hydration: hydration(water: 0),
                          hydrationTarget: 2000) == nil)
    }

    @Test func balancedDayScoresFive() throws {
        let score = try #require(DietScore(intake: balancedDay, hydration: hydration(water: 2000),
                                           hydrationTarget: 2000))
        #expect(score.criteria.count == 6)
        #expect(score.criteria.allSatisfy { approx($0.score, 1) })
        #expect(score.value == 5)
        #expect(score.tips.isEmpty)
        #expect(score.headline == "Journée très équilibrée")
    }

    @Test func fortyGramsOfAlcoholZeroesTheAlcoholCriterion() throws {
        var intake = balancedDay
        intake.alcohol = 40
        let score = try #require(DietScore(intake: intake, hydration: hydration(water: 2000),
                                           hydrationTarget: 2000))
        let alcohol = try #require(score.criteria.first { $0.title == "Alcool" })
        #expect(alcohol.score == 0)
        // Cinq critères à 1, un à 0 : moyenne 5/6 → 4,17 sur 5, arrondi au demi-point → 4.
        #expect(score.value == 4)
        #expect(score.tips.count == 1)
        #expect(score.tips.first?.hasPrefix("Alcool") == true)
    }

    @Test func tipsKeepTheTwoWeakestCriteria() throws {
        var intake = balancedDay
        intake.fiber = 0          // fibres : 0
        intake.sugar = 125        // sucres 25 % : 0,33
        let score = try #require(DietScore(intake: intake, hydration: hydration(water: 1000),
                                           hydrationTarget: 2000))   // hydratation : 0,5
        #expect(score.tips.count == 2)
        #expect(score.tips[0].hasPrefix("Fibres"))
        #expect(score.tips[1].hasPrefix("Sucres"))
    }

    @Test func proteinBandDecreasesLinearlyBelowIdeal() throws {
        var intake = balancedDay
        intake.protein = 50       // 10 % des calories : à mi-chemin entre 5 % (0) et 15 % (1)
        let score = try #require(DietScore(intake: intake, hydration: hydration(water: 2000),
                                           hydrationTarget: 2000))
        let protein = try #require(score.criteria.first { $0.title == "Protéines" })
        #expect(approx(protein.score, 0.5))
    }

    @Test func noHydrationTargetCountsAsSatisfied() throws {
        let score = try #require(DietScore(intake: balancedDay, hydration: hydration(water: 0),
                                           hydrationTarget: 0))
        #expect(score.criteria.first { $0.title == "Hydratation" }?.score == 1)
    }
}
