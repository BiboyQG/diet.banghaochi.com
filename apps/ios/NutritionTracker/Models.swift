import Foundation

enum DayType: String, Codable, CaseIterable, Identifiable, Sendable {
    case training
    case rest

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum Sex: String, Codable, CaseIterable, Identifiable, Sendable {
    case male
    case female

    var id: String { rawValue }
}

enum MealSlot: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack
    case drink
    case supplement
    case other

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct Profile: Codable, Equatable, Sendable {
    var id: String
    var displayName: String
    var email: String
    var sex: Sex
    var age: Int
    var heightCm: Double
    var currentWeightKg: Double
    var timezone: String
    var activityFactor: Double
    var trainingExerciseKcal: Double
    var createdAt: String
    var updatedAt: String
}

struct DailyTarget: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var dayType: DayType
    var burnKcal: Double
    var intakeKcal: Double
    var deficitKcal: Double
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var waterMl: Double
    var createdAt: String
    var updatedAt: String
}

struct Entry: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var dayLogId: String
    var loggedAt: String
    var mealSlot: MealSlot
    var name: String
    var caloriesKcal: Double
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var waterMl: Double
    var notes: String?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct BodyWeight: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var localDate: String
    var measuredAt: String
    var weightKg: Double
    var notes: String?
    var createdAt: String
    var updatedAt: String
}

struct EntryTotals: Codable, Equatable, Sendable {
    var caloriesKcal: Double
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var waterMl: Double
}

struct DayCalculated: Codable, Equatable, Sendable {
    var remainingIntakeKcal: Double
    var actualDeficitKcal: Double
}

struct DayLog: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var localDate: String
    var dayType: DayType
    var burnKcal: Double
    var intakeTargetKcal: Double
    var deficitTargetKcal: Double
    var carbsTargetG: Double
    var proteinTargetG: Double
    var fatTargetG: Double
    var waterTargetMl: Double
    var notes: String?
    var createdAt: String
    var updatedAt: String
    var totals: EntryTotals
    var calculated: DayCalculated
    var entries: [Entry]
    var bodyWeight: BodyWeight?
}

struct Summary: Codable, Equatable, Sendable {
    struct Averages: Codable, Equatable, Sendable {
        var caloriesKcal: Double
        var proteinG: Double
        var waterMl: Double
    }

    struct Counts: Codable, Equatable, Sendable {
        var days: Int
        var training: Int
        var rest: Int
    }

    var start: String
    var end: String
    var days: [DayLog]
    var averages: Averages
    var counts: Counts
    var estimatedDeficitKcal: Double
}

struct DayPatchRequest: Codable, Equatable, Sendable {
    var dayType: DayType
}

struct ProfilePatchRequest: Codable, Equatable, Sendable {
    var displayName: String?
    var email: String?
    var sex: Sex?
    var age: Int?
    var heightCm: Double?
    var currentWeightKg: Double?
    var timezone: String?
    var activityFactor: Double?
    var trainingExerciseKcal: Double?
}

struct TargetPatchRequest: Codable, Equatable, Sendable {
    var burnKcal: Double?
    var intakeKcal: Double?
    var deficitKcal: Double?
    var carbsG: Double?
    var proteinG: Double?
    var fatG: Double?
    var waterMl: Double?
}

struct EntryCreateRequest: Codable, Equatable, Sendable {
    var localDate: String
    var loggedAt: String
    var mealSlot: MealSlot
    var name: String
    var caloriesKcal: Double
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var waterMl: Double
    var notes: String?
}

struct EntryPatchRequest: Codable, Equatable, Sendable {
    var loggedAt: String?
    var mealSlot: MealSlot?
    var name: String?
    var caloriesKcal: Double?
    var carbsG: Double?
    var proteinG: Double?
    var fatG: Double?
    var waterMl: Double?
    var notes: String?
}

struct EntryMutationResponse: Codable, Equatable, Sendable {
    var entry: Entry
    var day: DayLog
    var warnings: [String]?
}

struct EntryDeleteResponse: Codable, Equatable, Sendable {
    var entry: Entry
    var day: DayLog
}

struct BodyWeightCreateRequest: Codable, Equatable, Sendable {
    var localDate: String
    var measuredAt: String
    var weightKg: Double
    var notes: String?
}

struct EntryDraft: Equatable, Sendable {
    var mealSlot: MealSlot = .lunch
    var name = ""
    var caloriesKcal: Double = 0
    var carbsG: Double = 0
    var proteinG: Double = 0
    var fatG: Double = 0
    var waterMl: Double = 0
    var notes: String?

    init(
        mealSlot: MealSlot = .lunch,
        name: String = "",
        caloriesKcal: Double = 0,
        carbsG: Double = 0,
        proteinG: Double = 0,
        fatG: Double = 0,
        waterMl: Double = 0,
        notes: String? = nil
    ) {
        self.mealSlot = mealSlot
        self.name = name
        self.caloriesKcal = caloriesKcal
        self.carbsG = carbsG
        self.proteinG = proteinG
        self.fatG = fatG
        self.waterMl = waterMl
        self.notes = notes
    }

    init(entry: Entry) {
        mealSlot = entry.mealSlot
        name = entry.name
        caloriesKcal = entry.caloriesKcal
        carbsG = entry.carbsG
        proteinG = entry.proteinG
        fatG = entry.fatG
        waterMl = entry.waterMl
        notes = entry.notes
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            caloriesKcal >= 0 &&
            carbsG >= 0 &&
            proteinG >= 0 &&
            fatG >= 0 &&
            waterMl >= 0
    }

    func request(localDate: String, now: Date = Date()) -> EntryCreateRequest {
        EntryCreateRequest(
            localDate: localDate,
            loggedAt: ISO8601DateFormatter().string(from: now),
            mealSlot: mealSlot,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            caloriesKcal: caloriesKcal,
            carbsG: carbsG,
            proteinG: proteinG,
            fatG: fatG,
            waterMl: waterMl,
            notes: notes
        )
    }

    var patchRequest: EntryPatchRequest {
        EntryPatchRequest(
            loggedAt: nil,
            mealSlot: mealSlot,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            caloriesKcal: caloriesKcal,
            carbsG: carbsG,
            proteinG: proteinG,
            fatG: fatG,
            waterMl: waterMl,
            notes: notes
        )
    }
}
