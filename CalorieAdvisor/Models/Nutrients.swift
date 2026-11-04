import Foundation

/// Valeurs nutritionnelles pour une quantité donnée (kcal et grammes).
nonisolated struct Nutrients: Hashable, Codable, Sendable {
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var sugar: Double = 0
    var alcohol: Double = 0

    static let zero = Nutrients()

    func scaled(by factor: Double) -> Nutrients {
        Nutrients(kcal: kcal * factor, protein: protein * factor, carbs: carbs * factor,
                  fat: fat * factor, fiber: fiber * factor, sugar: sugar * factor,
                  alcohol: alcohol * factor)
    }

    static func + (lhs: Nutrients, rhs: Nutrients) -> Nutrients {
        Nutrients(kcal: lhs.kcal + rhs.kcal, protein: lhs.protein + rhs.protein,
                  carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat,
                  fiber: lhs.fiber + rhs.fiber, sugar: lhs.sugar + rhs.sugar,
                  alcohol: lhs.alcohol + rhs.alcohol)
    }

    /// kcal calculées à partir des macros (4/4/9/7).
    var kcalFromMacros: Double { protein * 4 + carbs * 4 + fat * 9 + alcohol * 7 }

    /// Grammes d'alcool pur pour un volume (ml) et un degré (% vol). Densité de l'éthanol : 0,789.
    static func alcoholGrams(volumeML: Double, abv: Double) -> Double {
        volumeML * abv / 100 * 0.789
    }
}

extension Sequence where Element == Nutrients {
    var total: Nutrients { reduce(.zero, +) }
}
