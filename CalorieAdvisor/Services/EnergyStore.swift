import Foundation
import HealthKit
import Observation

/// Dépense énergétique d'une journée.
struct DayEnergy {
    enum BasalSource {
        /// Valeur mesurée par Santé (Apple Watch).
        case health
        /// Journée en cours : valeur Santé extrapolée à 24 h.
        case projected
        /// Pas (assez) de données : formule de Mifflin-St Jeor.
        case estimated
    }

    var active: Double
    var basal: Double
    var basalSource: BasalSource
    var total: Double { active + basal }
}

/// Lecture des calories dépensées et du poids dans Apple Santé.
@Observable
@MainActor
final class EnergyStore {
    private let store = HKHealthStore()
    private let calendar = Calendar.current

    private(set) var latestWeight: Double?
    var isHealthAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.activeEnergyBurned), HKQuantityType(.basalEnergyBurned), HKQuantityType(.bodyMass)]
    }

    func requestAuthorization() async {
        guard isHealthAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            print("HealthKit authorization failed: \(error)")
        }
    }

    func energy(on day: Date) async -> DayEnergy {
        let map = await energy(from: day, through: day)
        return map[calendar.startOfDay(for: day)] ?? DayEnergy(active: 0, basal: 0, basalSource: .estimated)
    }

    /// Dépense par jour (clé = début de journée) entre deux dates incluses. Les jours futurs sont ignorés.
    func energy(from start: Date, through end: Date) async -> [Date: DayEnergy] {
        let profile = UserProfile.load()
        let first = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: .now)
        let last = min(calendar.startOfDay(for: end), today)
        guard first <= last, let rangeEnd = calendar.date(byAdding: .day, value: 1, to: last) else { return [:] }

        let useHealth = profile.healthKitEnabled && isHealthAvailable
        var active: [Date: Double] = [:]
        var basal: [Date: Double] = [:]
        if useHealth {
            active = await dailySums(.activeEnergyBurned, from: first, to: rangeEnd)
            basal = await dailySums(.basalEnergyBurned, from: first, to: rangeEnd)
            if latestWeight == nil { latestWeight = await fetchLatestWeight() }
        }
        let bmr = profile.bmr(weightKg: latestWeight)

        var result: [Date: DayEnergy] = [:]
        var day = first
        while day <= last {
            let measuredBasal = basal[day] ?? 0
            let dayActive = active[day] ?? 0
            let energy: DayEnergy
            if !useHealth {
                // Sans Santé : métabolisme de base × 1,2 (sédentaire), sans activité mesurée.
                energy = DayEnergy(active: 0, basal: bmr * 1.2, basalSource: .estimated)
            } else if day == today {
                let fraction = Date.now.timeIntervalSince(today) / 86_400
                if measuredBasal > 0 && fraction > 0.2 {
                    energy = DayEnergy(active: dayActive, basal: measuredBasal / fraction, basalSource: .projected)
                } else {
                    energy = DayEnergy(active: dayActive, basal: bmr, basalSource: .estimated)
                }
            } else if measuredBasal >= bmr * 0.6 {
                energy = DayEnergy(active: dayActive, basal: measuredBasal, basalSource: .health)
            } else {
                // Montre non portée une partie de la journée : on se rabat sur la formule.
                energy = DayEnergy(active: dayActive, basal: bmr, basalSource: .estimated)
            }
            result[day] = energy
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }

    /// Poids moyen par jour (kg) sur la période, pour les jours où une pesée existe.
    func dailyWeights(from start: Date, through end: Date) async -> [Date: Double] {
        guard isHealthAvailable, UserProfile.load().healthKitEnabled else { return [:] }
        let first = calendar.startOfDay(for: start)
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
        return await dailyStatistics(.bodyMass, options: .discreteAverage, unit: .gramUnit(with: .kilo),
                                     from: first, to: rangeEnd)
    }

    // MARK: - Requêtes

    private func dailySums(_ id: HKQuantityTypeIdentifier, from start: Date, to end: Date) async -> [Date: Double] {
        await dailyStatistics(id, options: .cumulativeSum, unit: .kilocalorie(), from: start, to: end)
    }

    private func dailyStatistics(_ id: HKQuantityTypeIdentifier, options: HKStatisticsOptions, unit: HKUnit,
                                 from start: Date, to end: Date) async -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: predicate),
            options: options,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1))
        do {
            let collection = try await descriptor.result(for: store)
            var values: [Date: Double] = [:]
            for stats in collection.statistics() {
                let quantity = options.contains(.cumulativeSum) ? stats.sumQuantity() : stats.averageQuantity()
                if let quantity {
                    values[calendar.startOfDay(for: stats.startDate)] = quantity.doubleValue(for: unit)
                }
            }
            return values
        } catch {
            print("HealthKit query \(id.rawValue) failed: \(error)")
            return [:]
        }
    }

    private func fetchLatestWeight() async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1)
        let samples = try? await descriptor.result(for: store)
        return samples?.first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }
}
