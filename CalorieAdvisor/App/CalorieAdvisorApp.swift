import SwiftData
import SwiftUI

@main
struct CalorieAdvisorApp: App {
    @State private var energyStore = EnergyStore()

    init() {
        ProfileKey.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(energyStore)
        }
        .modelContainer(for: [FoodEntry.self, SavedFood.self])
    }
}

struct RootView: View {
    @Environment(EnergyStore.self) private var energyStore
    @AppStorage(ProfileKey.healthKitEnabled) private var healthKitEnabled = true

    var body: some View {
        TabView {
            Tab("Journal", systemImage: "fork.knife") { JournalView() }
            Tab("Tendances", systemImage: "chart.bar.xaxis") { TrendsView() }
            Tab("Conseils", systemImage: "sparkles") { InsightsView() }
            Tab("Réglages", systemImage: "gearshape") { SettingsView() }
        }
        .task {
            if healthKitEnabled { await energyStore.requestAuthorization() }
        }
    }
}
