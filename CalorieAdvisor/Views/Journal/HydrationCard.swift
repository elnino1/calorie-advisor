import SwiftData
import SwiftUI

/// Cumul des boissons de la journée par catégorie, objectif et ajout rapide.
struct HydrationCard: View {
    let entries: [FoodEntry]
    let day: Date

    @Environment(\.modelContext) private var context
    @Environment(EnergyStore.self) private var energyStore
    @AppStorage(ProfileKey.hydrationTarget) private var customTarget = 0.0
    @AppStorage(ProfileKey.weightKg) private var weightKg = 75.0
    @AppStorage(ProfileKey.isMale) private var isMale = true

    /// Boissons de la base intégrée proposées en ajout rapide.
    private let quickDrinks: [(label: String, symbol: String, name: String, quantity: Double)] = [
        ("Eau 25 cl", "drop.fill", "Eau", 250),
        ("Café", "cup.and.saucer.fill", "Café noir", 100),
        ("Thé", "mug.fill", "Thé", 250),
    ]

    private var target: Double {
        customTarget > 0
            ? customTarget
            : HydrationGoal.automatic(weightKg: energyStore.latestWeight ?? weightKg, isMale: isMale)
    }

    var body: some View {
        let summary = HydrationSummary(entries: entries)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Hydratation", systemImage: "drop.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Spacer()
                Text("\(summary.hydrating.litersText) / \(target.litersText)")
                    .monospacedDigit()
                    .bold()
            }

            ProgressView(value: min(summary.hydrating / max(target, 1), 1))
                .tint(summary.hydrating >= target ? Color.green : Color.blue)

            HStack(spacing: 12) {
                ForEach(DrinkCategory.allCases) { category in
                    let volume = summary.volume(category)
                    if category != .alcohol || volume > 0 {
                        Label(volume.litersText, systemImage: category.symbol)
                            .font(.caption)
                            .foregroundStyle(category.color)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }

            HStack {
                ForEach(quickDrinks, id: \.name) { drink in
                    Button {
                        add(name: drink.name, quantity: drink.quantity)
                    } label: {
                        Label(drink.label, systemImage: drink.symbol)
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }

            if summary.volume(.alcohol) > 0 {
                Text("L'alcool n'est pas compté dans l'hydratation.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func add(name: String, quantity: Double) {
        guard let template = FoodDatabase.shared.exactMatch(name) else { return }
        FoodLogger.log(template, quantity: quantity, meal: .drinks, day: day, in: context)
    }
}
