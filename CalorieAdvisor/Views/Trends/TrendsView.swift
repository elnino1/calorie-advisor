import Charts
import SwiftData
import SwiftUI

struct TrendsView: View {
    @State private var days = 30

    var body: some View {
        NavigationStack {
            TrendsContent(days: days)
                .id(days)
                .navigationTitle("Tendances")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Période", selection: $days) {
                            Text("7 j").tag(7)
                            Text("30 j").tag(30)
                            Text("3 mois").tag(90)
                            Text("1 an").tag(365)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                    }
                }
        }
    }
}

private struct TrendsContent: View {
    let days: Int
    private let start: Date
    private let today = Calendar.current.startOfDay(for: .now)

    @Environment(EnergyStore.self) private var energyStore
    private var goal = CalorieGoal()
    private var targetDeficit: Double { goal.dailyDeficit(latestWeight: energyStore.latestWeight) }
    @Query private var entries: [FoodEntry]
    @State private var energy: [Date: DayEnergy] = [:]
    @State private var weights: [Date: Double] = [:]

    init(days: Int) {
        self.days = days
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: .now))!
        self.start = start
        _entries = Query(filter: #Predicate<FoodEntry> { $0.timestamp >= start }, sort: \FoodEntry.timestamp)
    }

    /// Journées complètes (aujourd'hui exclu) ayant au moins une saisie.
    private var stats: [DayStats] {
        DayStats.build(entries: entries, energy: energy).filter { $0.day < today && $0.balance != nil }
    }

    var body: some View {
        let stats = self.stats
        ScrollView {
            NavigationLink {
                ReportsView()
            } label: {
                Label("Bilans par semaine et par mois", systemImage: "calendar")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding([.horizontal, .top])
            if stats.isEmpty {
                ContentUnavailableView("Pas encore de données", systemImage: "chart.bar",
                                       description: Text("Les journées complètes saisies apparaîtront ici."))
                    .padding(.top, 60)
            } else {
                VStack(spacing: 16) {
                    summaryTiles(stats)
                    card("Balance quotidienne", subtitle: "Vert : objectif atteint · jaune : insuffisant · orange : sens inverse") { balanceChart(stats) }
                    card("Apport et dépense", subtitle: "kcal par jour") { intakeChart(stats) }
                    card("Balance cumulée", subtitle: "Équivalent estimé en kg (7 700 kcal ≈ 1 kg)") { cumulativeChart(stats) }
                    card("Hydratation", subtitle: "Boissons sans alcool par jour ; objectif en pointillés") { hydrationChart(stats) }
                    if weights.count >= 2 {
                        card("Poids (Apple Santé)", subtitle: nil) { weightChart }
                    }
                    card("Répartition moyenne des apports", subtitle: nil) { macroChart(stats) }
                    Text("Aujourd'hui est exclu car la journée n'est pas terminée ; seuls les jours avec au moins une saisie sont comptés.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .task {
            energy = await energyStore.energy(from: start, through: today)
            weights = await energyStore.dailyWeights(from: start, through: today)
        }
    }

    // MARK: - Tuiles

    private func summaryTiles(_ stats: [DayStats]) -> some View {
        let balances = stats.compactMap(\.balance)
        let avgBalance = balances.reduce(0, +) / Double(balances.count)
        let avgIntake = stats.map(\.intake.kcal).reduce(0, +) / Double(stats.count)
        let deficitDays = balances.filter { CalorieGoal.isOnTarget(balance: $0, deficit: targetDeficit) }.count
        let cumulative = balances.reduce(0, +)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            tile("Balance moyenne", "\(avgBalance > 0 ? "+" : "")\(avgBalance.kcalText) kcal",
                 color: avgBalance <= 0 ? .green : .orange)
            tile("Apport moyen", "\(avgIntake.kcalText) kcal", color: .blue)
            tile("Objectif atteint", "\(deficitDays) / \(stats.count) jours", color: .green)
            tile("Estimation", String(format: "%+.1f kg", cumulative / kcalPerKg),
                 color: cumulative <= 0 ? .green : .orange)
        }
    }

    private func tile(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).foregroundStyle(color).monospacedDigit()
                .minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func card<Content: View>(_ title: String, subtitle: String?,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            content().frame(height: 200)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Graphiques

    private func balanceChart(_ stats: [DayStats]) -> some View {
        Chart {
            ForEach(stats) { s in
                let balance = s.balance ?? 0
                BarMark(x: .value("Jour", s.day, unit: .day), y: .value("Balance", balance))
                    .foregroundStyle(CalorieGoal.status(balance: balance, deficit: targetDeficit).color)
            }
            RuleMark(y: .value("Objectif", -targetDeficit))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.secondary)
                .annotation(position: .bottom, alignment: .leading) {
                    Text("objectif").font(.caption2).foregroundStyle(.secondary)
                }
        }
    }

    private func intakeChart(_ stats: [DayStats]) -> some View {
        Chart {
            ForEach(stats) { s in
                LineMark(x: .value("Jour", s.day, unit: .day), y: .value("kcal", s.intake.kcal))
                    .foregroundStyle(by: .value("Série", "Apport"))
                LineMark(x: .value("Jour", s.day, unit: .day), y: .value("kcal", s.energy?.total ?? 0))
                    .foregroundStyle(by: .value("Série", "Dépense"))
            }
        }
        .chartForegroundStyleScale(["Apport": Color.blue, "Dépense": Color.orange])
    }

    private func cumulativeChart(_ stats: [DayStats]) -> some View {
        var running = 0.0
        let points: [(Date, Double)] = stats.map { s in
            running += s.balance ?? 0
            return (s.day, running / kcalPerKg)
        }
        return Chart {
            ForEach(points, id: \.0) { point in
                AreaMark(x: .value("Jour", point.0, unit: .day), y: .value("kg", point.1))
                    .foregroundStyle(Color.green.opacity(0.2))
                LineMark(x: .value("Jour", point.0, unit: .day), y: .value("kg", point.1))
                    .foregroundStyle(Color.green)
            }
        }
    }

    private func hydrationChart(_ stats: [DayStats]) -> some View {
        let target = HydrationGoal.current(latestWeight: energyStore.latestWeight)
        return Chart {
            ForEach(stats) { s in
                ForEach(DrinkCategory.allCases.filter { $0 != .alcohol }) { category in
                    BarMark(x: .value("Jour", s.day, unit: .day),
                            y: .value("L", s.hydration.volume(category) / 1000))
                        .foregroundStyle(by: .value("Boisson", category.title))
                }
            }
            RuleMark(y: .value("Objectif", target / 1000))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.secondary)
        }
        .chartForegroundStyleScale(["Eau": Color.blue, "Café / thé": Color.brown, "Autres": Color.teal])
    }

    private var weightChart: some View {
        let points = weights.sorted { $0.key < $1.key }
        let plan = goal.plan(latestWeight: energyStore.latestWeight)
        let values = points.map(\.value) + (plan.map { [$0.targetKg] } ?? [])
        let lower = (values.min() ?? 0) - 1, upper = (values.max() ?? 0) + 1
        return Chart {
            ForEach(points, id: \.key) { point in
                LineMark(x: .value("Jour", point.key, unit: .day), y: .value("kg", point.value))
                PointMark(x: .value("Jour", point.key, unit: .day), y: .value("kg", point.value))
                    .symbolSize(20)
            }
            if let plan {
                RuleMark(y: .value("Poids cible", plan.targetKg))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.green)
                    .annotation(position: .top, alignment: .leading) {
                        Text("cible \(plan.targetKg.formatted()) kg").font(.caption2).foregroundStyle(.green)
                    }
            }
        }
        .chartYScale(domain: lower...upper)
    }

    private func macroChart(_ stats: [DayStats]) -> some View {
        let total = stats.map(\.intake).total
        let allParts: [(String, Double, Color)] = [
            ("Protéines", total.protein * 4, .red),
            ("Glucides", total.carbs * 4, .blue),
            ("Lipides", total.fat * 9, .yellow),
            ("Alcool", total.alcohol * 7, .purple),
        ]
        let parts = allParts.filter { $0.1 > 0 }
        let sum = max(parts.map(\.1).reduce(0, +), 1)
        let n = Double(stats.count)
        return HStack {
            Chart(parts, id: \.0) { part in
                SectorMark(angle: .value("kcal", part.1), innerRadius: .ratio(0.6), angularInset: 1.5)
                    .foregroundStyle(part.2)
            }
            .frame(width: 150)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(parts, id: \.0) { part in
                    HStack {
                        Circle().fill(part.2).frame(width: 8, height: 8)
                        Text(part.0)
                        Spacer()
                        Text("\(Int((part.1 / sum * 100).rounded())) %").bold()
                    }
                    .font(.subheadline)
                }
                Divider()
                Text("Moyenne/jour : P \((total.protein / n).gramsText) g · G \((total.carbs / n).gramsText) g · L \((total.fat / n).gramsText) g · fibres \((total.fiber / n).gramsText) g")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
