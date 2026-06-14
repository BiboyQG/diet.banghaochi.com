import Foundation

struct ProfileAssumptions: Equatable, Sendable {
    var sex: Sex
    var age: Int
    var heightCm: Double
    var currentWeightKg: Double
    var activityFactor: Double
    var trainingExerciseKcal: Double
}

enum NutritionCalculations {
    static func bmr(_ profile: ProfileAssumptions) -> Double {
        let base = 10 * profile.currentWeightKg + 6.25 * profile.heightCm - 5 * Double(profile.age)
        switch profile.sex {
        case .male:
            return base + 5
        case .female:
            return base - 161
        }
    }

    static func restBurn(_ profile: ProfileAssumptions) -> Double {
        bmr(profile) * profile.activityFactor
    }

    static func trainingBurn(_ profile: ProfileAssumptions) -> Double {
        restBurn(profile) + profile.trainingExerciseKcal
    }

    static func plannedDeficit(burnKcal: Double, intakeTargetKcal: Double) -> Double {
        burnKcal - intakeTargetKcal
    }

    static func actualDeficit(burnKcal: Double, consumedKcal: Double) -> Double {
        burnKcal - consumedKcal
    }

    static func remainingIntake(intakeTargetKcal: Double, consumedKcal: Double) -> Double {
        intakeTargetKcal - consumedKcal
    }

    static func macroCalories(carbsG: Double, proteinG: Double, fatG: Double) -> Double {
        carbsG * 4 + proteinG * 4 + fatG * 9
    }

    static func shouldWarnMacroCalories(
        caloriesKcal: Double,
        carbsG: Double,
        proteinG: Double,
        fatG: Double
    ) -> Bool {
        let macroCalories = macroCalories(carbsG: carbsG, proteinG: proteinG, fatG: fatG)
        let difference = abs(macroCalories - caloriesKcal)
        return difference >= 100 && difference / max(caloriesKcal, 1) >= 0.2
    }
}

enum LocalDate {
    static func format(_ date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 1970,
            components.month ?? 1,
            components.day ?? 1
        )
    }

    static func addingDays(_ days: Int, to localDate: String, calendar: Calendar = .current) -> String {
        let parts = localDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return localDate }

        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        guard let date = calendar.date(from: components),
              let shifted = calendar.date(byAdding: .day, value: days, to: date)
        else {
            return localDate
        }

        return format(shifted, calendar: calendar)
    }
}
