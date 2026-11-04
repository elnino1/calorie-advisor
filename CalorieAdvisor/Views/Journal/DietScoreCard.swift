import SwiftUI

/// Note de composition de la journée et pistes d'amélioration.
struct DietScoreCard: View {
    let entries: [FoodEntry]
    let isToday: Bool

    @Environment(EnergyStore.self) private var energyStore

    var body: some View {
        let target = HydrationGoal.current(latestWeight: energyStore.latestWeight)
        if let score = DietScore(intake: entries.map(\.nutrients).total,
                                 hydration: HydrationSummary(entries: entries), hydrationTarget: target) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Composition").font(.headline)
                    if isToday { Text("(à ce stade)").font(.subheadline).foregroundStyle(.secondary) }
                    Spacer()
                    ScoreStars(value: score.value)
                    Text("\(score.value.scoreText)/5").bold().monospacedDigit()
                }
                Text(score.headline).font(.subheadline)
                ForEach(score.tips, id: \.self) { tip in
                    Label(tip, systemImage: "lightbulb")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else if !entries.isEmpty {
            Label("La note de composition s'affiche à partir de 300 kcal saisies.", systemImage: "star")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Cinq étoiles, demi-étoiles comprises.
struct ScoreStars: View {
    let value: Double

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<5) { index in
                let remaining = value - Double(index)
                Image(systemName: remaining >= 1 ? "star.fill" : remaining >= 0.5 ? "star.leadinghalf.filled" : "star")
            }
        }
        .font(.caption)
        .foregroundStyle(ScoreStars.color(for: value))
    }

    static func color(for value: Double) -> Color {
        switch value {
        case 4...: .green
        case 2.5..<4: .yellow
        default: .orange
        }
    }
}
