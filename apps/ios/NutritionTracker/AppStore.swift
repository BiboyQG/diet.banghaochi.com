import Foundation

@MainActor
@Observable
final class AppStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var state: LoadState = .idle
    var profile: Profile?
    var targets: [DailyTarget] = []
    var today: DayLog?
    var summary: Summary?

    private let client: NutritionAPIClient
    private let calendar: Calendar

    init(client: NutritionAPIClient, calendar: Calendar = .current) {
        self.client = client
        self.calendar = calendar
    }

    var todayLocalDate: String {
        LocalDate.format(Date(), calendar: calendar)
    }

    func load() async {
        state = .loading
        do {
            async let profile = client.fetchProfile()
            async let targets = client.fetchTargets()
            async let today = client.fetchDay(todayLocalDate)
            async let summary = client.fetchSummary(
                LocalDate.addingDays(-13, to: todayLocalDate, calendar: calendar),
                todayLocalDate
            )
            self.profile = try await profile
            self.targets = try await targets
            self.today = try await today
            self.summary = try await summary
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refreshToday() async {
        do {
            today = try await client.fetchDay(todayLocalDate)
            summary = try await client.fetchSummary(
                LocalDate.addingDays(-13, to: todayLocalDate, calendar: calendar),
                todayLocalDate
            )
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func setDayType(_ dayType: DayType) async {
        guard let today, today.dayType != dayType else { return }
        do {
            self.today = try await client.patchDay(today.localDate, DayPatchRequest(dayType: dayType))
            await refreshSummary()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func saveEntry(_ draft: EntryDraft) async {
        do {
            let response = try await client.createEntry(draft.request(localDate: todayLocalDate))
            today = response.day
            await refreshSummary()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func updateEntry(_ entry: Entry, draft: EntryDraft) async {
        do {
            let response = try await client.patchEntry(entry.id, draft.patchRequest)
            today = response.day
            await refreshSummary()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func deleteEntry(_ entry: Entry) async {
        do {
            let response = try await client.deleteEntry(entry.id)
            today = response.day
            await refreshSummary()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func saveBodyWeight(weightKg: Double, notes: String?) async {
        do {
            _ = try await client.addBodyWeight(
                BodyWeightCreateRequest(
                    localDate: todayLocalDate,
                    measuredAt: ISO8601DateFormatter().string(from: Date()),
                    weightKg: weightKg,
                    notes: notes
                )
            )
            await refreshToday()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func updateProfile(_ patch: ProfilePatchRequest) async {
        do {
            profile = try await client.patchProfile(patch)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func updateTarget(dayType: DayType, patch: TargetPatchRequest) async {
        do {
            let updated = try await client.patchTarget(dayType, patch)
            if let index = targets.firstIndex(where: { $0.dayType == dayType }) {
                targets[index] = updated
            } else {
                targets.append(updated)
                targets.sort { $0.dayType.rawValue < $1.dayType.rawValue }
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func addWater(_ milliliters: Double) async {
        let draft = EntryDraft(
            mealSlot: .drink,
            name: "Water \(Int(milliliters)) ml",
            caloriesKcal: 0,
            carbsG: 0,
            proteinG: 0,
            fatG: 0,
            waterMl: milliliters
        )
        await saveEntry(draft)
    }

    private func refreshSummary() async {
        do {
            summary = try await client.fetchSummary(
                LocalDate.addingDays(-13, to: todayLocalDate, calendar: calendar),
                todayLocalDate
            )
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

extension AppStore {
    static var previewLoaded: AppStore {
        let store = AppStore(client: .mock())
        store.state = .loaded
        store.profile = .fixture
        store.targets = DailyTarget.fixtures
        store.today = .fixture
        store.summary = .fixture
        return store
    }
}
