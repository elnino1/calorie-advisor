import SwiftUI

/// Plan pour atteindre un poids cible à un rythme hebdomadaire donné.
struct WeightPlan {
    let currentKg: Double
    let targetKg: Double
    /// Rythme choisi, en kg par semaine (valeur positive).
    let weeklyPaceKg: Double
    let heightCm: Double

    /// Déficit quotidien maximal appliqué, par prudence.
    static let maxDailyDeficit = 1000.0

    /// Négatif = poids à perdre, positif = poids à prendre.
    var deltaKg: Double { targetKg - currentKg }
    var isReached: Bool { abs(deltaKg) < 0.5 }
    var isLoss: Bool { deltaKg < 0 }

    /// Rythme effectif après plafonnement du déficit.
    var effectivePaceKg: Double { min(weeklyPaceKg, Self.maxDailyDeficit * 7 / kcalPerKg) }

    /// Déficit quotidien visé (négatif = surplus pour une prise de poids, 0 = maintien).
    var dailyDeficit: Double {
        guard !isReached else { return 0 }
        let kcal = effectivePaceKg * kcalPerKg / 7
        return isLoss ? kcal : -kcal
    }

    var weeksRemaining: Double { isReached ? 0 : abs(deltaKg) / effectivePaceKg }

    var estimatedDate: Date {
        Calendar.current.date(byAdding: .day, value: Int((weeksRemaining * 7).rounded()), to: .now) ?? .now
    }

    /// Plus de 1 % du poids par semaine : rythme difficile à tenir et déconseillé.
    var isAggressive: Bool { weeklyPaceKg > currentKg * 0.01 }

    var targetBMI: Double {
        let meters = heightCm / 100
        return meters > 0 ? targetKg / (meters * meters) : 0
    }

    var summary: String {
        if isReached { return "Poids cible atteint : objectif de maintien." }
        let verb = isLoss ? "perdre" : "prendre"
        return "\(abs(deltaKg).formatted(.number.precision(.fractionLength(1)))) kg à \(verb) à \(effectivePaceKg.formatted()) kg/semaine, arrivée estimée le \(estimatedDate.formatted(date: .long, time: .omitted))."
    }
}

/// Objectif calorique courant : déficit manuel, ou déduit du poids cible.
/// Utilisable comme propriété d'une vue (se met à jour quand les réglages changent).
struct CalorieGoal: DynamicProperty {
    @AppStorage(ProfileKey.targetDeficit) var manualDeficit = 500.0
    @AppStorage(ProfileKey.weightGoalEnabled) var weightGoalEnabled = false
    @AppStorage(ProfileKey.targetWeightKg) var targetWeightKg = 70.0
    @AppStorage(ProfileKey.weeklyPaceKg) var weeklyPaceKg = 0.5
    @AppStorage(ProfileKey.weightKg) var profileWeightKg = 75.0
    @AppStorage(ProfileKey.heightCm) var heightCm = 175.0

    func plan(latestWeight: Double?) -> WeightPlan? {
        guard weightGoalEnabled else { return nil }
        return WeightPlan(currentKg: latestWeight ?? profileWeightKg, targetKg: targetWeightKg,
                          weeklyPaceKg: weeklyPaceKg, heightCm: heightCm)
    }

    /// Déficit quotidien visé (négatif = surplus).
    func dailyDeficit(latestWeight: Double?) -> Double {
        plan(latestWeight: latestWeight)?.dailyDeficit ?? manualDeficit
    }

    /// Libellé court : "déficit 500 kcal", "surplus 250 kcal" ou "maintien".
    static func label(for deficit: Double) -> String {
        if abs(deficit) < 1 { return "maintien" }
        return deficit > 0 ? "déficit \(deficit.kcalText) kcal" : "surplus \(abs(deficit).kcalText) kcal"
    }

    /// Une journée respecte-t-elle l'objectif ? (tolérance de 200 kcal pour le maintien)
    static func isOnTarget(balance: Double, deficit: Double) -> Bool {
        if abs(deficit) < 1 { return abs(balance) <= 200 }
        return deficit > 0 ? balance <= -deficit : balance >= -deficit
    }
}
