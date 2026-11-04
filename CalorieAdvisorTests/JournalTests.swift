import Foundation
import Testing
@testable import CalorieAdvisor

struct DrinkTests {
    @Test(arguments: [
        ("Eau plate", 0.0, DrinkCategory.water),
        ("Café", 0, .hot),
        ("Thé vert", 0, .hot),
        ("Jus d'orange", 0, .other),
        ("Bière blonde", 10, .alcohol)
    ])
    func category(name: String, alcohol: Double, expected: DrinkCategory) {
        #expect(DrinkCategory.of(name: name, alcohol: alcohol) == expected)
    }

    @Test func soupsAreNotDrinks() {
        #expect(DrinkCategory.of(name: "Soupe de légumes", alcohol: 0) == nil)
        #expect(DrinkCategory.of(name: "Velouté de potiron", alcohol: 0) == nil)
    }

    @Test func automaticHydrationGoal() {
        #expect(HydrationGoal.automatic(weightKg: 70, isMale: true) == 2000)     // 1 960 → minimum 2 L
        #expect(HydrationGoal.automatic(weightKg: 90, isMale: true) == 2500)     // 2 520 → arrondi à 50 ml
        #expect(HydrationGoal.automatic(weightKg: 50, isMale: false) == 1600)    // 1 400 → minimum 1,6 L
    }

    @Test func alcoholIsNotHydrating() {
        let summary = HydrationSummary(entries: [
            entry("Eau plate", unit: .milliliter, quantity: 500, nutrients: .zero),
            entry("Café", unit: .milliliter, quantity: 100, nutrients: .zero),
            entry("Vin rouge", unit: .milliliter, quantity: 150, nutrients: Nutrients(kcal: 85, alcohol: 10)),
            entry("Pain", quantity: 50)
        ])
        #expect(summary.volume(.water) == 500)
        #expect(summary.volume(.alcohol) == 150)
        #expect(summary.hydrating == 600)
    }
}

struct FoodEntryTests {
    @Test func nutrientsFollowTheQuantity() {
        let food = entry("Riz", quantity: 150, nutrients: Nutrients(kcal: 130, carbs: 28))
        #expect(approx(food.nutrients.kcal, 195))
        #expect(approx(food.nutrients.carbs, 42))
        food.quantity = 50
        #expect(approx(food.nutrients.kcal, 65))
    }

    @Test func overrideTotalsSetsValuesForTheCurrentQuantity() {
        let food = entry("Plat maison", quantity: 300)
        food.overrideTotals(Nutrients(kcal: 600, protein: 30))
        #expect(approx(food.nutrients.kcal, 600))
        #expect(approx(food.nutrients.protein, 30))
    }

    @Test func drinksGoToTheDrinksSection() {
        #expect(entry("Eau plate", unit: .milliliter, meal: .lunch).journalSection == .drinks)
        #expect(entry("Soupe de légumes", unit: .milliliter, meal: .dinner).journalSection == .dinner)
        #expect(entry("Pain", meal: .breakfast).journalSection == .breakfast)
    }

    @Test func templateRoundTrip() {
        let food = entry("Yaourt", quantity: 125, nutrients: Nutrients(kcal: 60, protein: 4))
        let copy = food.template
        #expect(copy.name == "Yaourt")
        #expect(copy.defaultQuantity == 125)
        #expect(approx(copy.nutrients(for: 125).kcal, food.nutrients.kcal))
    }
}

struct DayStatsTests {
    @Test func entriesAreGroupedByDayWithBalance() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let entries = [
            entry("Pâtes", nutrients: Nutrients(kcal: 800), at: today.addingTimeInterval(3600 * 12)),
            entry("Pomme", nutrients: Nutrients(kcal: 50), at: today.addingTimeInterval(3600 * 16)),
            entry("Pizza", nutrients: Nutrients(kcal: 900), at: yesterday.addingTimeInterval(3600 * 20))
        ]
        let energy = [today: DayEnergy(active: 500, basal: 1700, basalSource: .health)]
        let stats = DayStats.build(entries: entries, energy: energy)

        #expect(stats.map(\.day) == [yesterday, today])
        #expect(stats[0].intake.kcal == 900)
        #expect(stats[0].balance == nil)                  // pas de dépense connue
        #expect(stats[1].intake.kcal == 850)
        let expectedBalance: Double = 850 - 2200          // déficit de 1 350 kcal
        #expect(stats[1].balance == expectedBalance)
    }
}

struct FoodDatabaseTests {
    @Test func bundledDatabaseIsLoaded() {
        #expect(FoodDatabase.shared.foods.count > 100)
    }

    @Test func searchPutsPrefixMatchesFirstAndIgnoresAccents() throws {
        let results = FoodDatabase.shared.search("pain")
        let first = try #require(results.first)
        #expect(first.name.searchKey.hasPrefix("pain"))
        #expect(!FoodDatabase.shared.search("cafe").isEmpty)
        #expect(FoodDatabase.shared.search("  ").isEmpty)
    }

    @Test func exactMatchToleratesPlural() {
        #expect(FoodDatabase.shared.exactMatch("Croissants")?.name == "Croissant")
        #expect(FoodDatabase.shared.exactMatch("croissant")?.name == "Croissant")
        #expect(FoodDatabase.shared.exactMatch("plat introuvable") == nil)
    }
}
