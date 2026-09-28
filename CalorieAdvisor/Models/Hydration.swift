import Foundation
import SwiftUI

/// Catégorie d'une boisson, déduite de son nom et de sa teneur en alcool.
enum DrinkCategory: String, CaseIterable, Identifiable {
    case water, hot, other, alcohol

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water: "Eau"
        case .hot: "Café / thé"
        case .other: "Autres"
        case .alcohol: "Alcool"
        }
    }

    var symbol: String {
        switch self {
        case .water: "drop.fill"
        case .hot: "cup.and.saucer.fill"
        case .other: "takeoutbag.and.cup.and.straw.fill"
        case .alcohol: "wineglass.fill"
        }
    }

    var color: Color {
        switch self {
        case .water: .blue
        case .hot: .brown
        case .other: .teal
        case .alcohol: .purple
        }
    }

    private static let hotPrefixes = ["cafe", "cappuccino", "expresso", "espresso", "latte", "the", "tisane",
                                      "infusion", "chocolat chaud"]
    private static let notDrinks = ["soupe", "veloute", "potage", "bouillon"]

    /// `nil` si l'aliment liquide n'est pas une boisson (soupe…).
    static func of(name: String, alcohol: Double) -> DrinkCategory? {
        let key = name.searchKey
        if notDrinks.contains(where: { key.contains($0) }) { return nil }
        if alcohol > 0 { return .alcohol }
        if key.hasPrefix("eau") { return .water }
        if hotPrefixes.contains(where: { key.hasPrefix($0) }) { return .hot }
        return .other
    }
}

extension FoodEntry {
    /// Catégorie de boisson pour les entrées exprimées en ml.
    var drinkCategory: DrinkCategory? {
        unit == .milliliter ? DrinkCategory.of(name: name, alcohol: refAlcohol) : nil
    }

    /// Section du journal : toutes les boissons sont regroupées dans « Boissons »,
    /// y compris celles saisies avant l'existence de cette section.
    var journalSection: MealType {
        meal == .drinks || drinkCategory != nil ? .drinks : meal
    }
}

extension FoodTemplate {
    var isDrink: Bool {
        unit == .milliliter && DrinkCategory.of(name: name, alcohol: nutrients.alcohol) != nil
    }
}

/// Volumes bus sur un ensemble d'entrées (ml).
struct HydrationSummary {
    private(set) var volumes: [DrinkCategory: Double] = [:]

    init(entries: [FoodEntry]) {
        for entry in entries {
            if let category = entry.drinkCategory { volumes[category, default: 0] += entry.quantity }
        }
    }

    func volume(_ category: DrinkCategory) -> Double { volumes[category] ?? 0 }

    /// Boissons comptées pour l'hydratation (l'alcool est exclu).
    var hydrating: Double { volume(.water) + volume(.hot) + volume(.other) }
}

enum HydrationGoal {
    /// Objectif de boissons (ml/jour) : ≈ 35 ml/kg d'eau au total, dont ≈ 80 % apportés par les boissons,
    /// avec pour minimum les repères EFSA (2 L d'eau de boisson pour un homme, 1,6 L pour une femme).
    static func automatic(weightKg: Double, isMale: Bool) -> Double {
        let byWeight = weightKg * 35 * 0.8
        let minimum = isMale ? 2000.0 : 1600.0
        return (max(byWeight, minimum) / 50).rounded() * 50
    }

    /// Objectif personnalisé s'il est défini (> 0), sinon automatique.
    static func current(latestWeight: Double?) -> Double {
        let custom = UserDefaults.standard.double(forKey: ProfileKey.hydrationTarget)
        if custom > 0 { return custom }
        let profile = UserProfile.load()
        return automatic(weightKg: latestWeight ?? profile.weightKg, isMale: profile.isMale)
    }
}

extension Double {
    /// ml → "1,25 L".
    var litersText: String {
        "\((self / 1000).formatted(.number.precision(.fractionLength(0...2)))) L"
    }
}
