import Foundation

struct NutritionAPIClient: Sendable {
    var fetchProfile: @Sendable () async throws -> Profile
    var patchProfile: @Sendable (_ patch: ProfilePatchRequest) async throws -> Profile
    var fetchTargets: @Sendable () async throws -> [DailyTarget]
    var patchTarget: @Sendable (_ dayType: DayType, _ patch: TargetPatchRequest) async throws -> DailyTarget
    var fetchDay: @Sendable (_ localDate: String) async throws -> DayLog
    var patchDay: @Sendable (_ localDate: String, _ patch: DayPatchRequest) async throws -> DayLog
    var createEntry: @Sendable (_ entry: EntryCreateRequest) async throws -> EntryMutationResponse
    var patchEntry: @Sendable (_ id: String, _ patch: EntryPatchRequest) async throws -> EntryMutationResponse
    var deleteEntry: @Sendable (_ id: String) async throws -> EntryDeleteResponse
    var fetchFoodTemplates: @Sendable () async throws -> [FoodTemplate]
    var createFoodTemplate: @Sendable (_ template: FoodTemplateCreateRequest) async throws -> FoodTemplate
    var patchFoodTemplate: @Sendable (_ id: String, _ patch: FoodTemplatePatchRequest) async throws -> FoodTemplate
    var deleteFoodTemplate: @Sendable (_ id: String) async throws -> FoodTemplate
    var logFoodTemplate: @Sendable (_ id: String, _ request: FoodTemplateLogRequest) async throws -> FoodTemplateLogResponse
    var addBodyWeight: @Sendable (_ weight: BodyWeightCreateRequest) async throws -> BodyWeight
    var fetchSummary: @Sendable (_ start: String, _ end: String) async throws -> Summary

    static func live(
        baseURL: URL = URL(string: "http://localhost:8787/api/v1/")!,
        session: URLSession = .shared,
        accessCookie: (@Sendable () async -> String?)? = nil
    ) -> NutritionAPIClient {
        let transport = HTTPTransport(
            baseURL: baseURL,
            session: session,
            accessCookie: accessCookie
        )
        return NutritionAPIClient(
            fetchProfile: {
                try await transport.get("profile")
            },
            patchProfile: { patch in
                try await transport.send("profile", method: "PATCH", body: patch)
            },
            fetchTargets: {
                try await transport.get("targets")
            },
            patchTarget: { dayType, patch in
                try await transport.send("targets/\(dayType.rawValue)", method: "PATCH", body: patch)
            },
            fetchDay: { localDate in
                try await transport.get("days/\(localDate)")
            },
            patchDay: { localDate, patch in
                try await transport.send("days/\(localDate)", method: "PATCH", body: patch)
            },
            createEntry: { entry in
                try await transport.send("entries", method: "POST", body: entry)
            },
            patchEntry: { id, patch in
                try await transport.send("entries/\(id)", method: "PATCH", body: patch)
            },
            deleteEntry: { id in
                try await transport.send("entries/\(id)", method: "DELETE", body: Optional<EmptyBody>.none)
            },
            fetchFoodTemplates: {
                try await transport.get("food-templates")
            },
            createFoodTemplate: { template in
                try await transport.send("food-templates", method: "POST", body: template)
            },
            patchFoodTemplate: { id, patch in
                try await transport.send("food-templates/\(id)", method: "PATCH", body: patch)
            },
            deleteFoodTemplate: { id in
                try await transport.send("food-templates/\(id)", method: "DELETE", body: Optional<EmptyBody>.none)
            },
            logFoodTemplate: { id, request in
                try await transport.send("food-templates/\(id)/log", method: "POST", body: request)
            },
            addBodyWeight: { weight in
                try await transport.send("body-weights", method: "POST", body: weight)
            },
            fetchSummary: { start, end in
                try await transport.get("summary?start=\(start)&end=\(end)")
            }
        )
    }

    static func mock(
        profile: Profile = .fixture,
        targets: [DailyTarget] = DailyTarget.fixtures,
        day: DayLog = .fixture,
        foodTemplates: [FoodTemplate] = FoodTemplate.fixtures,
        summary: Summary = .fixture
    ) -> NutritionAPIClient {
        let state = MockFoodTemplateState(templates: foodTemplates)

        return NutritionAPIClient(
            fetchProfile: { profile },
            patchProfile: { patch in
                Profile(
                    id: profile.id,
                    displayName: patch.displayName ?? profile.displayName,
                    email: patch.email ?? profile.email,
                    sex: patch.sex ?? profile.sex,
                    age: patch.age ?? profile.age,
                    heightCm: patch.heightCm ?? profile.heightCm,
                    currentWeightKg: patch.currentWeightKg ?? profile.currentWeightKg,
                    timezone: patch.timezone ?? profile.timezone,
                    activityFactor: patch.activityFactor ?? profile.activityFactor,
                    trainingExerciseKcal: patch.trainingExerciseKcal ?? profile.trainingExerciseKcal,
                    createdAt: profile.createdAt,
                    updatedAt: profile.updatedAt
                )
            },
            fetchTargets: { targets },
            patchTarget: { dayType, patch in
                guard let target = targets.first(where: { $0.dayType == dayType }) else {
                    throw APIError.httpStatus(404)
                }
                return DailyTarget(
                    id: target.id,
                    dayType: target.dayType,
                    burnKcal: patch.burnKcal ?? target.burnKcal,
                    intakeKcal: patch.intakeKcal ?? target.intakeKcal,
                    deficitKcal: patch.deficitKcal ?? target.deficitKcal,
                    carbsG: patch.carbsG ?? target.carbsG,
                    proteinG: patch.proteinG ?? target.proteinG,
                    fatG: patch.fatG ?? target.fatG,
                    waterMl: patch.waterMl ?? target.waterMl,
                    createdAt: target.createdAt,
                    updatedAt: target.updatedAt
                )
            },
            fetchDay: { _ in day },
            patchDay: { _, patch in
                var updated = day
                updated.dayType = patch.dayType
                return updated
            },
            createEntry: { request in
                let entry = Entry.fixture(from: request)
                var updatedDay = day
                updatedDay.entries = [entry] + updatedDay.entries
                return EntryMutationResponse(entry: entry, day: updatedDay.recalculated(), warnings: [])
            },
            patchEntry: { id, patch in
                var updatedDay = day
                guard let index = updatedDay.entries.firstIndex(where: { $0.id == id }) else {
                    throw APIError.httpStatus(404)
                }
                var entry = updatedDay.entries[index]
                entry.mealSlot = patch.mealSlot ?? entry.mealSlot
                entry.name = patch.name ?? entry.name
                entry.caloriesKcal = patch.caloriesKcal ?? entry.caloriesKcal
                entry.carbsG = patch.carbsG ?? entry.carbsG
                entry.proteinG = patch.proteinG ?? entry.proteinG
                entry.fatG = patch.fatG ?? entry.fatG
                entry.waterMl = patch.waterMl ?? entry.waterMl
                entry.notes = patch.notes ?? entry.notes
                updatedDay.entries[index] = entry
                return EntryMutationResponse(entry: entry, day: updatedDay.recalculated(), warnings: [])
            },
            deleteEntry: { id in
                var updatedDay = day
                guard let index = updatedDay.entries.firstIndex(where: { $0.id == id }) else {
                    throw APIError.httpStatus(404)
                }
                var entry = updatedDay.entries.remove(at: index)
                entry.deletedAt = entry.updatedAt
                return EntryDeleteResponse(entry: entry, day: updatedDay.recalculated())
            },
            fetchFoodTemplates: {
                await state.all()
            },
            createFoodTemplate: { request in
                await state.create(request)
            },
            patchFoodTemplate: { id, patch in
                try await state.patch(id: id, patch: patch)
            },
            deleteFoodTemplate: { id in
                try await state.delete(id: id)
            },
            logFoodTemplate: { id, request in
                let template = try await state.log(id: id, at: request.loggedAt)

                let entry = Entry.fixture(
                    from: EntryCreateRequest(
                        localDate: request.localDate,
                        loggedAt: request.loggedAt,
                        mealSlot: request.mealSlot ?? template.mealSlot,
                        name: template.name,
                        caloriesKcal: template.caloriesKcal,
                        carbsG: template.carbsG,
                        proteinG: template.proteinG,
                        fatG: template.fatG,
                        waterMl: template.waterMl,
                        notes: template.notes
                    )
                )
                var updatedDay = day
                updatedDay.entries = [entry] + updatedDay.entries
                return FoodTemplateLogResponse(
                    template: template,
                    entry: entry,
                    day: updatedDay.recalculated(),
                    warnings: []
                )
            },
            addBodyWeight: { request in
                BodyWeight(
                    id: "weight-\(UUID().uuidString)",
                    localDate: request.localDate,
                    measuredAt: request.measuredAt,
                    weightKg: request.weightKg,
                    notes: request.notes,
                    createdAt: request.measuredAt,
                    updatedAt: request.measuredAt
                )
            },
            fetchSummary: { _, _ in summary }
        )
    }
}

private extension DayLog {
    func recalculated() -> DayLog {
        var day = self
        day.totals = entries.reduce(
            EntryTotals(caloriesKcal: 0, carbsG: 0, proteinG: 0, fatG: 0, waterMl: 0)
        ) { totals, entry in
            EntryTotals(
                caloriesKcal: totals.caloriesKcal + entry.caloriesKcal,
                carbsG: totals.carbsG + entry.carbsG,
                proteinG: totals.proteinG + entry.proteinG,
                fatG: totals.fatG + entry.fatG,
                waterMl: totals.waterMl + entry.waterMl
            )
        }
        day.calculated = DayCalculated(
            remainingIntakeKcal: day.intakeTargetKcal - day.totals.caloriesKcal,
            actualDeficitKcal: day.burnKcal - day.totals.caloriesKcal
        )
        return day
    }
}

private actor MockFoodTemplateState {
    private var templates: [FoodTemplate]

    init(templates: [FoodTemplate]) {
        self.templates = templates
    }

    func all() -> [FoodTemplate] {
        templates
    }

    func create(_ request: FoodTemplateCreateRequest) -> FoodTemplate {
        let template = FoodTemplate.fixture(from: request)
        templates = [template] + templates
        return template
    }

    func patch(id: String, patch: FoodTemplatePatchRequest) throws -> FoodTemplate {
        guard let index = templates.firstIndex(where: { $0.id == id }) else {
            throw APIError.httpStatus(404)
        }
        var template = templates[index]
        template.mealSlot = patch.mealSlot ?? template.mealSlot
        template.name = patch.name ?? template.name
        template.caloriesKcal = patch.caloriesKcal ?? template.caloriesKcal
        template.carbsG = patch.carbsG ?? template.carbsG
        template.proteinG = patch.proteinG ?? template.proteinG
        template.fatG = patch.fatG ?? template.fatG
        template.waterMl = patch.waterMl ?? template.waterMl
        template.notes = patch.notes ?? template.notes
        templates[index] = template
        return template
    }

    func delete(id: String) throws -> FoodTemplate {
        guard let index = templates.firstIndex(where: { $0.id == id }) else {
            throw APIError.httpStatus(404)
        }
        var template = templates.remove(at: index)
        template.deletedAt = template.updatedAt
        return template
    }

    func log(id: String, at loggedAt: String) throws -> FoodTemplate {
        guard let index = templates.firstIndex(where: { $0.id == id }) else {
            throw APIError.httpStatus(404)
        }
        var template = templates[index]
        template.usageCount += 1
        template.lastUsedAt = loggedAt
        templates[index] = template
        return template
    }
}

private struct HTTPTransport: Sendable {
    let baseURL: URL
    let session: URLSession
    let accessCookie: (@Sendable () async -> String?)?

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await send(path, method: "GET", body: Optional<EmptyBody>.none)
    }

    func send<T: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        body: Body?
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessCookie = await accessCookie?(), !accessCookie.isEmpty {
            request.setValue("CF_Authorization=\(accessCookie)", forHTTPHeaderField: "Cookie")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.nutrition.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpStatus(httpResponse.statusCode)
        }

        return try JSONDecoder.nutrition.decode(T.self, from: data)
    }
}

private struct EmptyBody: Encodable {}

enum APIError: Error, LocalizedError, Equatable {
    case invalidURL(String)
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            "Invalid API path: \(path)"
        case .invalidResponse:
            "Invalid API response"
        case .httpStatus(let status):
            "API request failed with status \(status)"
        }
    }
}

extension JSONDecoder {
    static var nutrition: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

extension JSONEncoder {
    static var nutrition: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
