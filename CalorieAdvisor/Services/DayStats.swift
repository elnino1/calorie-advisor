import Foundation

/// Bilan d'une journée : apports, dépense et balance.
struct DayStats: Identifiable {
    var day: Date
    var intake: Nutrients
    var energy: DayEnergy?
    var hydration: HydrationSummary
    var id: Date { day }

    /// Négatif = déficit, positif = surplus.
    var balance: Double? { energy.map { intake.kcal - $0.total } }

    static func build(entries: [FoodEntry], energy: [Date: DayEnergy]) -> [DayStats] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.timestamp) }
        return grouped.map { day, items in
            DayStats(day: day, intake: items.map(\.nutrients).total, energy: energy[day],
                     hydration: HydrationSummary(entries: items))
        }
        .sorted { $0.day < $1.day }
    }
}

extension Double {
    /// "1 234" (entier, séparateur de milliers français).
    var kcalText: String { Int(rounded()).formatted() }
    var gramsText: String { self < 10 ? formatted(.number.precision(.fractionLength(0...1))) : Int(rounded()).formatted() }
}
