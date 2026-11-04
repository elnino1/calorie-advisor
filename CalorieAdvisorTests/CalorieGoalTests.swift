import Foundation
import Testing
@testable import CalorieAdvisor

struct WeightPlanTests {
    private func plan(_ current: Double, _ target: Double, pace: Double = 0.5) -> WeightPlan {
        WeightPlan(currentKg: current, targetKg: target, weeklyPaceKg: pace, heightCm: 180)
    }

    @Test func lossGivesADailyDeficit() {
        let goal = plan(80, 75)
        #expect(goal.isLoss)
        #expect(!goal.isReached)
        #expect(approx(goal.dailyDeficit, 0.5 * kcalPerKg / 7))   // 550 kcal
        #expect(approx(goal.weeksRemaining, 10))
    }

    @Test func gainGivesASurplus() {
        let goal = plan(60, 65)
        #expect(!goal.isLoss)
        #expect(approx(goal.dailyDeficit, -550))
    }

    @Test func withinHalfAKiloIsMaintenance() {
        let goal = plan(70.3, 70)
        #expect(goal.isReached)
        #expect(goal.dailyDeficit == 0)
        #expect(goal.weeksRemaining == 0)
    }

    @Test func deficitIsCappedAt1000Kcal() {
        let goal = plan(100, 80, pace: 1)
        #expect(approx(goal.dailyDeficit, WeightPlan.maxDailyDeficit))
        #expect(goal.effectivePaceKg < 1)
    }

    @Test func aggressivePaceAndBMI() {
        #expect(plan(80, 75, pace: 1).isAggressive)       // > 1 % du poids par semaine
        #expect(!plan(80, 75, pace: 0.5).isAggressive)
        #expect(approx(plan(80, 75).targetBMI, 75 / (1.8 * 1.8)))
    }
}

struct CalorieGoalTests {
    @Test func label() {
        #expect(CalorieGoal.label(for: 0) == "maintien")
        #expect(CalorieGoal.label(for: 500) == "déficit 500 kcal")
        #expect(CalorieGoal.label(for: -250) == "surplus 250 kcal")
    }

    @Test func deficitGoal() {
        #expect(CalorieGoal.status(balance: -600, deficit: 500) == .onTarget)
        #expect(CalorieGoal.status(balance: -200, deficit: 500) == .partial)
        #expect(CalorieGoal.status(balance: 100, deficit: 500) == .off)
    }

    @Test func surplusGoal() {
        #expect(CalorieGoal.status(balance: 300, deficit: -250) == .onTarget)
        #expect(CalorieGoal.status(balance: 100, deficit: -250) == .partial)
        #expect(CalorieGoal.status(balance: -100, deficit: -250) == .off)
    }

    @Test func maintenanceTolerates200Kcal() {
        #expect(CalorieGoal.isOnTarget(balance: 200, deficit: 0))
        #expect(CalorieGoal.isOnTarget(balance: -200, deficit: 0))
        #expect(!CalorieGoal.isOnTarget(balance: 201, deficit: 0))
    }
}

struct UserProfileTests {
    @Test func mifflinStJeor() {
        let year = Calendar.current.component(.year, from: .now)
        let man = UserProfile(isMale: true, birthYear: year - 40, heightCm: 180, weightKg: 80,
                              targetDeficit: 500, healthKitEnabled: false)
        // 10 × poids + 6,25 × taille − 5 × âge, + 5 (homme) ou − 161 (femme)
        let manExpected: Double = 800 + 1125 - 200 + 5        // 1 730
        #expect(approx(man.bmr(), manExpected))
        var woman = man
        woman.isMale = false
        let womanExpected: Double = 600 + 1125 - 200 - 161    // 1 364
        #expect(approx(woman.bmr(weightKg: 60), womanExpected))
    }
}
