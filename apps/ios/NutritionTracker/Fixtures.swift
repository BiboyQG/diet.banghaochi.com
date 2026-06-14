import Foundation

extension Profile {
    static let fixture = Profile(
        id: "profile",
        displayName: "Owner",
        email: "replace-me@example.com",
        sex: .male,
        age: 25,
        heightCm: 170,
        currentWeightKg: 70,
        timezone: "America/Chicago",
        activityFactor: 1.2,
        trainingExerciseKcal: 650,
        createdAt: "2026-06-14T00:00:00.000Z",
        updatedAt: "2026-06-14T00:00:00.000Z"
    )
}

extension DailyTarget {
    static let training = DailyTarget(
        id: "target-training",
        dayType: .training,
        burnKcal: 2620,
        intakeKcal: 2100,
        deficitKcal: 520,
        carbsG: 250,
        proteinG: 140,
        fatG: 60,
        waterMl: 3000,
        createdAt: "2026-06-14T00:00:00.000Z",
        updatedAt: "2026-06-14T00:00:00.000Z"
    )

    static let rest = DailyTarget(
        id: "target-rest",
        dayType: .rest,
        burnKcal: 1970,
        intakeKcal: 1700,
        deficitKcal: 270,
        carbsG: 160,
        proteinG: 140,
        fatG: 55,
        waterMl: 2300,
        createdAt: "2026-06-14T00:00:00.000Z",
        updatedAt: "2026-06-14T00:00:00.000Z"
    )

    static let fixtures = [training, rest]
}

extension Entry {
    static let fixture = Entry(
        id: "entry-fixture",
        dayLogId: "day-fixture",
        loggedAt: "2026-06-14T12:00:00.000Z",
        mealSlot: .lunch,
        name: "Chicken rice",
        caloriesKcal: 600,
        carbsG: 65,
        proteinG: 42,
        fatG: 16,
        waterMl: 250,
        notes: nil,
        createdAt: "2026-06-14T12:00:00.000Z",
        updatedAt: "2026-06-14T12:00:00.000Z",
        deletedAt: nil
    )

    static func fixture(from request: EntryCreateRequest) -> Entry {
        Entry(
            id: "entry-\(UUID().uuidString)",
            dayLogId: "day-fixture",
            loggedAt: request.loggedAt,
            mealSlot: request.mealSlot,
            name: request.name,
            caloriesKcal: request.caloriesKcal,
            carbsG: request.carbsG,
            proteinG: request.proteinG,
            fatG: request.fatG,
            waterMl: request.waterMl,
            notes: request.notes,
            createdAt: request.loggedAt,
            updatedAt: request.loggedAt,
            deletedAt: nil
        )
    }
}

extension FoodTemplate {
    static let chipotle = FoodTemplate(
        id: "template-chipotle-bowl",
        mealSlot: .lunch,
        name: "Chipotle half barbacoa + honey chicken bowl",
        caloriesKcal: 540,
        carbsG: 54.5,
        proteinG: 28.5,
        fatG: 20.5,
        waterMl: 0,
        notes: "White rice, fresh tomato salsa, romaine lettuce, sour cream, no beans.",
        usageCount: 0,
        lastUsedAt: nil,
        createdAt: "2026-06-14T00:00:00.000Z",
        updatedAt: "2026-06-14T00:00:00.000Z",
        deletedAt: nil
    )

    static let fixtures = [chipotle]

    static func fixture(from request: FoodTemplateCreateRequest) -> FoodTemplate {
        FoodTemplate(
            id: "template-\(UUID().uuidString)",
            mealSlot: request.mealSlot,
            name: request.name,
            caloriesKcal: request.caloriesKcal,
            carbsG: request.carbsG,
            proteinG: request.proteinG,
            fatG: request.fatG,
            waterMl: request.waterMl,
            notes: request.notes,
            usageCount: 0,
            lastUsedAt: nil,
            createdAt: "2026-06-14T00:00:00.000Z",
            updatedAt: "2026-06-14T00:00:00.000Z",
            deletedAt: nil
        )
    }
}

extension DayLog {
    static let fixture = DayLog(
        id: "day-fixture",
        localDate: "2026-06-14",
        dayType: .training,
        burnKcal: 2620,
        intakeTargetKcal: 2100,
        deficitTargetKcal: 520,
        carbsTargetG: 250,
        proteinTargetG: 140,
        fatTargetG: 60,
        waterTargetMl: 3000,
        notes: nil,
        createdAt: "2026-06-14T00:00:00.000Z",
        updatedAt: "2026-06-14T00:00:00.000Z",
        totals: EntryTotals(
            caloriesKcal: 600,
            carbsG: 65,
            proteinG: 42,
            fatG: 16,
            waterMl: 250
        ),
        calculated: DayCalculated(
            remainingIntakeKcal: 1500,
            actualDeficitKcal: 2020
        ),
        entries: [.fixture],
        bodyWeight: BodyWeight(
            id: "weight-fixture",
            localDate: "2026-06-14",
            measuredAt: "2026-06-14T07:00:00.000Z",
            weightKg: 70,
            notes: nil,
            createdAt: "2026-06-14T07:00:00.000Z",
            updatedAt: "2026-06-14T07:00:00.000Z"
        )
    )
}

extension Summary {
    static let fixture = Summary(
        start: "2026-06-01",
        end: "2026-06-14",
        days: [.fixture],
        averages: Averages(caloriesKcal: 600, proteinG: 42, waterMl: 250),
        counts: Counts(days: 1, training: 1, rest: 0),
        estimatedDeficitKcal: 2020
    )
}
