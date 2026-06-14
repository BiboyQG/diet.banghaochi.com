import XCTest
@testable import NutritionTracker

final class CalculationTests: XCTestCase {
    func testBMRFormula() {
        let profile = ProfileAssumptions(
            sex: .male,
            age: 25,
            heightCm: 170,
            currentWeightKg: 70,
            activityFactor: 1.2,
            trainingExerciseKcal: 650
        )

        XCTAssertEqual(NutritionCalculations.bmr(profile), 1642.5)
        XCTAssertEqual(NutritionCalculations.restBurn(profile).rounded(), 1971)
        XCTAssertEqual(NutritionCalculations.trainingBurn(profile).rounded(), 2621)
    }

    func testDeficitAndMacroMath() {
        XCTAssertEqual(
            NutritionCalculations.plannedDeficit(burnKcal: 2620, intakeTargetKcal: 2100),
            520
        )
        XCTAssertEqual(
            NutritionCalculations.actualDeficit(burnKcal: 2620, consumedKcal: 1800),
            820
        )
        XCTAssertEqual(
            NutritionCalculations.remainingIntake(intakeTargetKcal: 2100, consumedKcal: 2200),
            -100
        )
        XCTAssertEqual(
            NutritionCalculations.macroCalories(carbsG: 10, proteinG: 20, fatG: 5),
            165
        )
        XCTAssertTrue(
            NutritionCalculations.shouldWarnMacroCalories(
                caloriesKcal: 600,
                carbsG: 10,
                proteinG: 20,
                fatG: 5
            )
        )
    }

    func testLocalDateShift() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!

        XCTAssertEqual(LocalDate.addingDays(-13, to: "2026-06-14", calendar: calendar), "2026-06-01")
    }
}
