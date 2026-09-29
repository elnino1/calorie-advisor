import Foundation

/// Repère de fibres (ANSES, adulte) en g/jour.
let fiberTarget = 30.0

/// Note de 0 à 5 sur la composition de la journée (aliments et boissons), avec des pistes
/// d'amélioration. Calcul déterministe à partir des repères ANSES / OMS, pour pouvoir noter
/// n'importe quel jour passé et agréger les notes dans les bilans.
struct DietScore {
    struct Criterion {
        let title: String
        /// 0 (très loin du repère) à 1 (repère atteint).
        let score: Double
        /// Constat chiffré et conseil, affiché si le critère n'est pas satisfait.
        let advice: String
    }

    let criteria: [Criterion]

    /// Note arrondie au demi-point.
    var value: Double {
        let mean = criteria.map(\.score).reduce(0, +) / Double(max(criteria.count, 1))
        return (mean * 10).rounded() / 2
    }

    /// Conseils des deux critères les plus faibles (hors critères satisfaits).
    var tips: [String] {
        criteria.filter { $0.score < 0.8 }.sorted { $0.score < $1.score }.prefix(2).map(\.advice)
    }

    var headline: String {
        switch value {
        case 4.5...: "Journée très équilibrée"
        case 3.5..<4.5: "Bonne composition, quelques ajustements possibles"
        case 2.5..<3.5: "Composition moyenne"
        default: "Composition à améliorer"
        }
    }

    /// `nil` si la journée est trop peu renseignée pour être notée.
    init?(intake: Nutrients, hydration: HydrationSummary, hydrationTarget: Double) {
        let kcal = intake.kcal
        guard kcal >= 300 else { return nil }
        func share(_ grams: Double, _ kcalPerGram: Double) -> Double { grams * kcalPerGram / kcal }
        func percent(_ value: Double) -> String { "\(Int((value * 100).rounded())) %" }

        let protein = share(intake.protein, 4)
        let sugar = share(intake.sugar, 4)
        let fat = share(intake.fat, 9)
        let drinks = intake.alcohol / 10

        criteria = [
            Criterion(title: "Protéines",
                      score: Self.band(protein, zeroBelow: 0.05, idealFrom: 0.15, idealTo: 0.30, zeroAbove: 0.45),
                      advice: protein < 0.15
                          ? "Protéines : \(percent(protein)) des calories, vise 15 à 25 % (œufs, poisson, viande maigre, légumineuses, yaourt, fromage blanc)."
                          : "Protéines : \(percent(protein)) des calories, c'est beaucoup ; rééquilibre avec des légumes et des féculents complets."),
            Criterion(title: "Fibres",
                      score: min(intake.fiber / fiberTarget, 1),
                      advice: "Fibres : \(intake.fiber.gramsText) g sur \(Int(fiberTarget)) g ; ajoute légumes, fruits, légumineuses et pain ou céréales complets."),
            Criterion(title: "Sucres",
                      score: Self.band(sugar, zeroBelow: -1, idealFrom: 0, idealTo: 0.15, zeroAbove: 0.30),
                      advice: "Sucres : \(intake.sugar.gramsText) g, soit \(percent(sugar)) des calories ; limite boissons sucrées, jus, desserts et viennoiseries."),
            Criterion(title: "Lipides",
                      score: Self.band(fat, zeroBelow: 0.10, idealFrom: 0.20, idealTo: 0.40, zeroAbove: 0.55),
                      advice: fat > 0.40
                          ? "Lipides : \(percent(fat)) des calories, au-delà du repère de 35 à 40 % ; allège fritures, sauces, charcuterie et fromage."
                          : "Lipides : \(percent(fat)) des calories, c'est peu ; une huile de colza ou d'olive, des noix ou un poisson gras apportent de bons acides gras."),
            Criterion(title: "Alcool",
                      score: max(1 - intake.alcohol / 40, 0),
                      advice: "Alcool : \(intake.alcohol.gramsText) g (≈ \(drinks.formatted(.number.precision(.fractionLength(0...1)))) verre(s) standard), soit \((intake.alcohol * 7).kcalText) kcal sans intérêt nutritionnel ; alterne avec de l'eau."),
            Criterion(title: "Hydratation",
                      score: hydrationTarget > 0 ? min(hydration.hydrating / hydrationTarget, 1) : 1,
                      advice: "Hydratation : \(hydration.hydrating.litersText) sur \(hydrationTarget.litersText) ; garde une bouteille d'eau à portée de main."),
        ]
    }

    /// 1 dans l'intervalle idéal, décroît linéairement jusqu'à 0 aux bornes extrêmes.
    private static func band(_ x: Double, zeroBelow: Double, idealFrom: Double, idealTo: Double,
                             zeroAbove: Double) -> Double {
        if x < idealFrom { return max((x - zeroBelow) / (idealFrom - zeroBelow), 0) }
        if x > idealTo { return max((zeroAbove - x) / (zeroAbove - idealTo), 0) }
        return 1
    }
}

extension DayStats {
    func dietScore(hydrationTarget: Double) -> DietScore? {
        DietScore(intake: intake, hydration: hydration, hydrationTarget: hydrationTarget)
    }
}

extension Double {
    /// Note → "3,5".
    var scoreText: String { formatted(.number.precision(.fractionLength(0...1))) }
}
