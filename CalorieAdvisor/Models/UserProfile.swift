import Foundation

enum ProfileKey {
    static let isMale = "profile.isMale"
    static let birthYear = "profile.birthYear"
    static let heightCm = "profile.heightCm"
    static let weightKg = "profile.weightKg"
    static let targetDeficit = "profile.targetDeficit"
    static let weightGoalEnabled = "profile.weightGoalEnabled"
    static let targetWeightKg = "profile.targetWeightKg"
    static let weeklyPaceKg = "profile.weeklyPaceKg"
    static let healthKitEnabled = "profile.healthKitEnabled"
    /// Objectif de boissons en ml/jour ; 0 = calcul automatique.
    static let hydrationTarget = "profile.hydrationTarget"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            isMale: true,
            birthYear: 1980,
            heightCm: 175.0,
            weightKg: 75.0,
            targetDeficit: 500.0,
            weightGoalEnabled: false,
            targetWeightKg: 70.0,
            weeklyPaceKg: 0.5,
            healthKitEnabled: true,
            hydrationTarget: 0.0,
        ])
    }
}

struct UserProfile {
    var isMale: Bool
    var birthYear: Int
    var heightCm: Double
    var weightKg: Double
    var targetDeficit: Double
    var healthKitEnabled: Bool

    static func load() -> UserProfile {
        let d = UserDefaults.standard
        return UserProfile(isMale: d.bool(forKey: ProfileKey.isMale),
                           birthYear: d.integer(forKey: ProfileKey.birthYear),
                           heightCm: d.double(forKey: ProfileKey.heightCm),
                           weightKg: d.double(forKey: ProfileKey.weightKg),
                           targetDeficit: d.double(forKey: ProfileKey.targetDeficit),
                           healthKitEnabled: d.bool(forKey: ProfileKey.healthKitEnabled))
    }

    var age: Int { Calendar.current.component(.year, from: .now) - birthYear }

    /// Métabolisme de base (Mifflin-St Jeor), en kcal/jour.
    func bmr(weightKg overrideWeight: Double? = nil) -> Double {
        let w = overrideWeight ?? weightKg
        return 10 * w + 6.25 * heightCm - 5 * Double(age) + (isMale ? 5 : -161)
    }
}

/// 1 kg de masse grasse ≈ 7 700 kcal.
let kcalPerKg = 7700.0
