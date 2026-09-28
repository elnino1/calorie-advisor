import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(EnergyStore.self) private var energyStore
    @AppStorage(ProfileKey.isMale) private var isMale = true
    @AppStorage(ProfileKey.birthYear) private var birthYear = 1980
    @AppStorage(ProfileKey.heightCm) private var heightCm = 175.0
    @AppStorage(ProfileKey.weightKg) private var weightKg = 75.0
    @AppStorage(ProfileKey.targetDeficit) private var targetDeficit = 500.0
    @AppStorage(ProfileKey.healthKitEnabled) private var healthKitEnabled = true
    @AppStorage(ProfileKey.hydrationTarget) private var hydrationTarget = 0.0
    @AppStorage(ProfileKey.weightGoalEnabled) private var weightGoalEnabled = false
    @AppStorage(ProfileKey.targetWeightKg) private var targetWeightKg = 70.0
    @AppStorage(ProfileKey.weeklyPaceKg) private var weeklyPaceKg = 0.5
    private var goal = CalorieGoal()

    private var profile: UserProfile { UserProfile.load() }

    private var automaticHydration: Double {
        HydrationGoal.automatic(weightKg: energyStore.latestWeight ?? weightKg, isMale: isMale)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Sexe", selection: $isMale) {
                        Text("Homme").tag(true)
                        Text("Femme").tag(false)
                    }
                    Stepper("Année de naissance : \(String(birthYear))", value: $birthYear, in: 1930...2015)
                    Stepper("Taille : \(Int(heightCm)) cm", value: $heightCm, in: 120...220)
                    Stepper("Poids : \(weightKg.formatted()) kg", value: $weightKg, in: 35...250, step: 0.5)
                } header: {
                    Text("Profil")
                } footer: {
                    Text("Sert à estimer le métabolisme de base (\(profile.bmr(weightKg: energyStore.latestWeight).kcalText) kcal/jour) quand Santé n'a pas de données. Le dernier poids enregistré dans Santé est utilisé en priorité.")
                }

                Section {
                    Toggle("Viser un poids cible", isOn: $weightGoalEnabled)
                    if let plan = goal.plan(latestWeight: energyStore.latestWeight) {
                        LabeledContent("Poids actuel", value: "\(plan.currentKg.formatted(.number.precision(.fractionLength(1)))) kg")
                        Stepper("Poids cible : \(targetWeightKg.formatted()) kg", value: $targetWeightKg,
                                in: 35...250, step: 0.5)
                        Picker("Rythme", selection: $weeklyPaceKg) {
                            ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { pace in
                                Text("\(pace.formatted()) kg/semaine").tag(pace)
                            }
                        }
                        LabeledContent("Objectif calorique", value: CalorieGoal.label(for: plan.dailyDeficit) + " / jour")
                        Text(plan.summary).font(.footnote)
                        if plan.isAggressive {
                            Label("Plus de 1 % du poids par semaine : rythme difficile à tenir, préférez un rythme plus lent.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        if plan.effectivePaceKg < weeklyPaceKg {
                            Label("Déficit plafonné à \(WeightPlan.maxDailyDeficit.kcalText) kcal/jour.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        if plan.targetBMI < 18.5 {
                            Label("Ce poids correspond à un IMC de \(plan.targetBMI.formatted(.number.precision(.fractionLength(1)))), inférieur à 18,5 (insuffisance pondérale). Demandez l'avis d'un professionnel de santé.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(.red)
                        }
                    } else {
                        VStack(alignment: .leading) {
                            Text("Déficit visé : \(targetDeficit.kcalText) kcal/jour")
                            Slider(value: $targetDeficit, in: 0...1000, step: 50)
                        }
                    }
                } header: {
                    Text("Objectif")
                } footer: {
                    if weightGoalEnabled {
                        Text("Le déficit (ou le surplus pour une prise de poids) est recalculé à partir du dernier poids enregistré dans Santé, sinon du poids du profil (1 kg ≈ 7 700 kcal). Le budget du jour = dépense − déficit visé.")
                    } else {
                        Text("≈ \(String(format: "%.2f", targetDeficit * 7 / kcalPerKg)) kg par semaine. Un déficit de plus de 1 000 kcal/jour est déconseillé sans suivi médical.")
                    }
                }

                Section {
                    Toggle("Objectif automatique", isOn: Binding(
                        get: { hydrationTarget == 0 },
                        set: { hydrationTarget = $0 ? 0 : automaticHydration }))
                    if hydrationTarget > 0 {
                        Stepper("Objectif : \(hydrationTarget.litersText)", value: $hydrationTarget,
                                in: 1000...5000, step: 250)
                    } else {
                        LabeledContent("Objectif", value: automaticHydration.litersText)
                    }
                } header: {
                    Text("Hydratation")
                } footer: {
                    Text("Calcul automatique selon le sexe et le poids : environ 35 ml d'eau par kg, dont 80 % apportés par les boissons, avec au moins 2 L pour un homme et 1,6 L pour une femme (repères EFSA). L'alcool n'est pas compté. Augmentez l'objectif en cas de forte chaleur ou de sport.")
                }

                Section {
                    Toggle("Utiliser Apple Santé", isOn: $healthKitEnabled)
                    if healthKitEnabled {
                        Button("Autoriser l'accès à Santé") {
                            Task { await energyStore.requestAuthorization() }
                        }
                    }
                } header: {
                    Text("Dépense énergétique")
                } footer: {
                    Text("Lit les calories actives et au repos (Apple Watch) ainsi que le poids. Pour modifier les autorisations : app Santé > Profil > Apps > Calories.")
                }

                Section("Apple Intelligence") {
                    LabeledContent("Statut", value: FoodIntelligence.statusText)
                }

                Section {
                    NavigationLink("Mes aliments et plats") { SavedFoodsView() }
                }

                Section("Application") {
                    LabeledContent("Version", value: Bundle.main.versionString)
                    if let expiry = ProvisioningInfo.expirationDate {
                        LabeledContent("Signature valide jusqu'au",
                                       value: expiry.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(expiry.timeIntervalSinceNow < 2 * 86_400 ? Color.red : Color.primary)
                    }
                }
            }
            .navigationTitle("Réglages")
        }
    }
}

struct SavedFoodsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedFood.name) private var foods: [SavedFood]

    var body: some View {
        List {
            ForEach(foods) { food in
                NavigationLink {
                    SavedFoodEditView(food: food)
                } label: {
                    VStack(alignment: .leading) {
                        Text(food.name)
                        Text("\(food.template.densityLabel) · utilisé \(food.useCount) fois")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets { context.delete(foods[index]) }
            }
        }
        .overlay {
            if foods.isEmpty {
                ContentUnavailableView("Aucun aliment enregistré", systemImage: "star",
                                       description: Text("Activez « Ajouter à mes aliments » lors d'un ajout, ou enregistrez un repas complet comme plat depuis le journal."))
            }
        }
        .navigationTitle("Mes aliments")
    }
}

private struct SavedFoodEditView: View {
    @Bindable var food: SavedFood

    var body: some View {
        Form {
            Section {
                TextField("Nom", text: $food.name)
                TextField("Marque", text: Binding(get: { food.brand ?? "" },
                                                  set: { food.brand = $0.isEmpty ? nil : $0 }))
                Picker("Unité", selection: $food.unit) {
                    ForEach(FoodUnit.allCases) { Text($0.label).tag($0) }
                }
                HStack {
                    Text("Portion habituelle")
                    Spacer()
                    TextField("", value: $food.defaultQuantity, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                    Text(food.unit.label).foregroundStyle(.secondary)
                }
            }
            Section("Valeurs pour \(food.referenceQuantity.formatted()) \(food.unit.label)") {
                NutrientFields(nutrients: $food.nutrients)
            }
        }
        .navigationTitle(food.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

/// Lit la date d'expiration du profil de provisionnement embarqué (7 jours avec un compte Apple gratuit).
enum ProvisioningInfo {
    static let expirationDate: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any]
        else { return nil }
        return plist["ExpirationDate"] as? Date
    }()
}
