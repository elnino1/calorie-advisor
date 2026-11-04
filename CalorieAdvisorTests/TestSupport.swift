import Foundation
@testable import CalorieAdvisor

/// Comparaison de flottants avec tolérance.
func approx(_ value: Double, _ expected: Double, tolerance: Double = 0.001) -> Bool {
    abs(value - expected) <= tolerance
}

/// Journée de 2 000 kcal conforme à tous les repères : protéines 20 %, sucres 10 %,
/// lipides 30 %, 30 g de fibres, sans alcool.
let balancedDay = Nutrients(kcal: 2000, protein: 100, carbs: 250, fat: 2000 * 0.30 / 9,
                            fiber: 30, sugar: 50, alcohol: 0)

func template(_ name: String, unit: FoodUnit = .gram, reference: Double = 100,
              nutrients: Nutrients = Nutrients(kcal: 100)) -> FoodTemplate {
    FoodTemplate(name: name, unit: unit, referenceQuantity: reference, nutrients: nutrients,
                 defaultQuantity: reference, source: .manual)
}

func entry(_ name: String, unit: FoodUnit = .gram, quantity: Double = 100,
           nutrients: Nutrients = Nutrients(kcal: 100), meal: MealType = .lunch,
           at timestamp: Date = .now) -> FoodEntry {
    FoodEntry(template: template(name, unit: unit, nutrients: nutrients), quantity: quantity,
              meal: meal, timestamp: timestamp)
}
