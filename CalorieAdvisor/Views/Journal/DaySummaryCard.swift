import SwiftUI

/// Synthèse du jour : apport, dépense, balance, répartition des macronutriments et fibres.
struct DaySummaryCard: View {
    let intake: Nutrients
    let energy: DayEnergy?
    let isToday: Bool

    @Environment(EnergyStore.self) private var energyStore
    private var goal = CalorieGoal()
    private var targetDeficit: Double { goal.dailyDeficit(latestWeight: energyStore.latestWeight) }

    private var burned: Double { energy?.total ?? 0 }
    private var balance: Double { intake.kcal - burned }
    private var budget: Double { max(burned - targetDeficit, 0) }
    private var progress: Double { budget > 0 ? min(intake.kcal / budget, 1.5) : 0 }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                ring
                VStack(alignment: .leading, spacing: 8) {
                    metric("Apport", intake.kcal, symbol: "fork.knife", color: .blue)
                    metric("Dépense", burned, symbol: "flame", color: .orange)
                    if let energy {
                        Text(energyDetail(energy))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            balanceBanner

            MacroBar(nutrients: intake)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20))
    }

    private var status: CalorieGoal.Status { CalorieGoal.status(balance: balance, deficit: targetDeficit) }
    private var remaining: Double { budget - intake.kcal }

    /// Budget du jour (dépense − déficit visé) : kcal restantes, ou dépassement en toutes lettres.
    private var ring: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(status.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(abs(remaining).kcalText)
                    .font(.title2.bold())
                    .monospacedDigit()
                Text(remaining >= 0 ? "restantes" : "au-dessus\ndu budget")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 110, height: 110)
        .animation(.snappy, value: progress)
    }

    private var balanceBanner: some View {
        let isDeficit = balance <= 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isDeficit ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                    .foregroundStyle(status.color)
                Text(isDeficit ? "Déficit" : "Surplus")
                if isToday { Text("(à ce stade)").foregroundStyle(.secondary) }
                Spacer()
                Text("\(abs(balance).kcalText) kcal").bold().monospacedDigit()
            }
            .font(.subheadline)
            Text(goalText).font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(status.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    /// Position par rapport à l'objectif, en mots.
    private var goalText: String {
        let gap = abs(balance + targetDeficit).kcalText
        if abs(targetDeficit) < 1 {
            return status == .onTarget ? "Maintien respecté (écart de moins de 200 kcal)"
                                       : "Objectif de maintien : écart de \(abs(balance).kcalText) kcal"
        }
        let goal = "Objectif : \(CalorieGoal.label(for: targetDeficit))"
        return switch status {
        case .onTarget: "\(goal), atteint (\(gap) kcal de marge)"
        case .partial: "\(goal), il manque \(gap) kcal"
        case .off: "\(goal), écart de \(gap) kcal"
        }
    }

    private func metric(_ title: String, _ value: Double, symbol: String, color: Color) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 20)
            Text(title)
            Spacer()
            Text("\(value.kcalText) kcal").monospacedDigit().bold()
        }
        .font(.subheadline)
    }

    private func energyDetail(_ e: DayEnergy) -> String {
        let basal: String = switch e.basalSource {
        case .health: "repos \(e.basal.kcalText)"
        case .projected: "repos \(e.basal.kcalText) (projeté sur 24 h)"
        case .estimated: "repos \(e.basal.kcalText) (estimé)"
        }
        return "Active \(e.active.kcalText) · \(basal) · objectif : \(CalorieGoal.label(for: targetDeficit))"
    }
}

struct MacroBar: View {
    let nutrients: Nutrients

    private var parts: [(String, Double, Double, Color)] {
        var parts: [(String, Double, Double, Color)] = [
            ("Protéines", nutrients.protein, nutrients.protein * 4, .red),
            ("Glucides", nutrients.carbs, nutrients.carbs * 4, .blue),
            ("Lipides", nutrients.fat, nutrients.fat * 9, .yellow),
        ]
        if nutrients.alcohol > 0 {
            parts.append(("Alcool", nutrients.alcohol, nutrients.alcohol * 7, .purple))
        }
        return parts
    }

    var body: some View {
        let totalKcal = max(parts.map(\.2).reduce(0, +), 1)
        VStack(spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(parts, id: \.0) { part in
                        part.3.frame(width: max(geo.size.width * part.2 / totalKcal - 2, 0))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
            .background(Capsule().fill(.quaternary))

            HStack {
                ForEach(parts, id: \.0) { part in
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Circle().fill(part.3).frame(width: 6, height: 6)
                            Text(part.0).font(.caption2).foregroundStyle(.secondary)
                        }
                        Text("\(part.1.gramsText) g").font(.caption.bold()).monospacedDigit()
                        Text("\(Int((part.2 / totalKcal * 100).rounded())) %")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                // Les fibres n'entrent pas dans la répartition des calories : affichées par rapport au repère.
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("Fibres").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("\(nutrients.fiber.gramsText) g").font(.caption.bold()).monospacedDigit()
                    Text("/ \(Int(fiberTarget)) g").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
