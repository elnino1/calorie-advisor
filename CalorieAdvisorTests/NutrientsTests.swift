import Foundation
import Testing
@testable import CalorieAdvisor

struct NutrientsTests {
    @Test func scalingMultipliesEveryValue() {
        let values = Nutrients(kcal: 200, protein: 10, carbs: 20, fat: 5, fiber: 2, sugar: 4, alcohol: 1)
        #expect(values.scaled(by: 1.5) == Nutrients(kcal: 300, protein: 15, carbs: 30, fat: 7.5,
                                                    fiber: 3, sugar: 6, alcohol: 1.5))
    }

    @Test func additionAndTotal() {
        let first = Nutrients(kcal: 100, protein: 1, carbs: 2, fat: 3, fiber: 4, sugar: 5, alcohol: 6)
        let second = Nutrients(kcal: 50, protein: 1, carbs: 1, fat: 1, fiber: 1, sugar: 1, alcohol: 1)
        #expect(first + second == Nutrients(kcal: 150, protein: 2, carbs: 3, fat: 4, fiber: 5, sugar: 6, alcohol: 7))
        #expect([first, second].total == first + second)
        #expect([Nutrients]().total == .zero)
    }

    @Test func kcalFromMacrosUses4_4_9_7() {
        let values = Nutrients(protein: 10, carbs: 10, fat: 10, alcohol: 10)
        #expect(values.kcalFromMacros == 40 + 40 + 90 + 70)
    }

    @Test func alcoholGramsFromVolumeAndABV() {
        // 25 cl de bière à 5 % : 250 × 0,05 × 0,789 ≈ 9,86 g d'alcool pur.
        #expect(approx(Nutrients.alcoholGrams(volumeML: 250, abv: 5), 9.8625))
        #expect(Nutrients.alcoholGrams(volumeML: 500, abv: 0) == 0)
    }
}
