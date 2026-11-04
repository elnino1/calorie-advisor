import Charts
import SwiftData
import SwiftUI

/// Bilans par semaine ou par mois : tendance déficit / surplus, évolution et note de composition.
struct ReportsView: View {
    enum Period: String, CaseIterable, Identifiable {
        case week, month
        var id: String { rawValue }
        var title: String { self == .week ? "Semaines" : "Mois" }
        var component: Calendar.Component { self == .week ? .weekOfYear : .month }
        var comparedTo: String { self == .week ? "à la semaine précédente" : "au mois précédent" }
    }

    @AppStorage("reports.period") private var period: Period = .week

    var body: some View {
        ReportsContent(period: period)
            .id(period)
            .navigationTitle("Bilans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Période", selection: $period) {
                        ForEach(Period.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }
    }
}

/// Bilan d'une semaine ou d'un mois (journées complètes avec au moins une saisie).
private struct PeriodReport: Identifiable {
    let start: Date
    let end: Date
    let days: [DayStats]
    let scores: [Double]
    var id: Date { start }

    var totalBalance: Double { days.compactMap(\.balance).reduce(0, +) }
    var averageBalance: Double { totalBalance / Double(days.count) }
    var averageScore: Double? { scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count) }
    var isCurrent: Bool { (start..<end).contains(.now) }
}

private struct ReportsContent: View {
    let period: ReportsView.Period
    private let start: Date
    private let today = Calendar.current.startOfDay(for: .now)

    @Environment(EnergyStore.self) private var energyStore
    private var goal = CalorieGoal()
    private var targetDeficit: Double { goal.dailyDeficit(latestWeight: energyStore.latestWeight) }
    @Query private var entries: [FoodEntry]
    @State private var energy: [Date: DayEnergy] = [:]

    init(period: ReportsView.Period) {
        self.period = period
        // 12 dernières semaines ou 12 derniers mois, période en cours comprise.
        let calendar = Calendar.current
        let current = calendar.dateInterval(of: period.component, for: .now)?.start ?? calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: period.component, value: -11, to: current)!
        self.start = start
        _entries = Query(filter: #Predicate<FoodEntry> { $0.timestamp >= start }, sort: \FoodEntry.timestamp)
    }

    private var reports: [PeriodReport] {
        let calendar = Calendar.current
        let hydrationTarget = HydrationGoal.current(latestWeight: energyStore.latestWeight)
        // Aujourd'hui est exclu, comme dans les tendances : la journée n'est pas terminée.
        let stats = DayStats.build(entries: entries, energy: energy).filter { $0.day < today && $0.balance != nil }
        let grouped = Dictionary(grouping: stats) { calendar.dateInterval(of: period.component, for: $0.day)! }
        return grouped.map { interval, days in
            PeriodReport(start: interval.start, end: interval.end, days: days,
                         scores: days.compactMap { $0.dietScore(hydrationTarget: hydrationTarget)?.value })
        }
        .sorted { $0.start < $1.start }
    }

    var body: some View {
        let reports = self.reports
        List {
            if reports.isEmpty {
                ContentUnavailableView("Pas encore de données", systemImage: "calendar",
                                       description: Text("Les journées complètes saisies apparaîtront ici."))
            } else {
                Section {
                    chart(reports)
                        .frame(height: 180)
                        .padding(.vertical, 8)
                } header: {
                    Text("Balance moyenne par jour")
                } footer: {
                    Text("Vert : objectif atteint · jaune : bon sens mais insuffisant · orange : sens inverse. Objectif en pointillés.")
                }

                Section {
                    // Plus récent en premier, comparé à la période précédente.
                    ForEach(Array(reports.enumerated().reversed()), id: \.element.id) { index, report in
                        row(report, previous: index > 0 ? reports[index - 1] : nil)
                    }
                } footer: {
                    Text("Seules les journées terminées avec au moins une saisie sont comptées. Équivalent en poids : 7 700 kcal ≈ 1 kg.")
                }
            }
        }
        .task {
            energy = await energyStore.energy(from: start, through: today)
        }
    }

    private func chart(_ reports: [PeriodReport]) -> some View {
        Chart {
            ForEach(reports) { report in
                BarMark(x: .value("Période", report.start, unit: period.component),
                        y: .value("Balance", report.averageBalance))
                    .foregroundStyle(CalorieGoal.status(balance: report.averageBalance, deficit: targetDeficit).color)
            }
            RuleMark(y: .value("Objectif", -targetDeficit))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.secondary)
        }
    }

    private func row(_ report: PeriodReport, previous: PeriodReport?) -> some View {
        let average = report.averageBalance
        let isDeficit = average <= 0
        let color = CalorieGoal.status(balance: average, deficit: targetDeficit).color
        let onTargetDays = report.days.compactMap(\.balance)
            .filter { CalorieGoal.isOnTarget(balance: $0, deficit: targetDeficit) }.count

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title(report)).font(.headline)
                if report.isCurrent { Text("(en cours)").font(.subheadline).foregroundStyle(.secondary) }
                Spacer()
                if let score = report.averageScore {
                    ScoreStars(value: (score * 2).rounded() / 2)
                    Text("\(score.scoreText)/5").font(.subheadline.bold()).monospacedDigit()
                }
            }
            HStack {
                Image(systemName: isDeficit ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                    .foregroundStyle(color)
                Text("\(isDeficit ? "Déficit" : "Surplus") de \(abs(average).kcalText) kcal/j")
                Spacer()
                Text(String(format: "%+.2f kg", report.totalBalance / kcalPerKg)).bold().monospacedDigit()
            }
            .font(.subheadline)

            Text("\(report.days.count) jour(s) · objectif atteint \(onTargetDays)/\(report.days.count) · total \(report.totalBalance > 0 ? "+" : "")\(report.totalBalance.kcalText) kcal")
                .font(.caption).foregroundStyle(.secondary)

            if let previous {
                trend(average: average, previous: previous.averageBalance)
            }
        }
        .padding(.vertical, 4)
    }

    /// Évolution de la balance moyenne ; « mieux » = plus proche de l'objectif.
    private func trend(average: Double, previous: Double) -> some View {
        let change = average - previous
        let improved = abs(average + targetDeficit) <= abs(previous + targetDeficit)
        let symbol = change <= 0 ? "arrow.down" : "arrow.up"
        return Label("\(change > 0 ? "+" : "−")\(abs(change).kcalText) kcal/j par rapport \(period.comparedTo)",
                     systemImage: symbol)
            .font(.caption)
            .foregroundStyle(abs(change) < 1 ? Color.secondary : improved ? Color.green : Color.orange)
    }

    private func title(_ report: PeriodReport) -> String {
        switch period {
        case .week: "Semaine du \(report.start.formatted(.dateTime.day().month()))"
        case .month: report.start.formatted(.dateTime.month(.wide).year()).capitalized
        }
    }
}
