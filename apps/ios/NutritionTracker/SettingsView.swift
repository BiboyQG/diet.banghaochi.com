import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(AuthSessionStore.self) private var auth
    @Environment(AppStore.self) private var store

    @State private var profileDraft = ProfileDraft()
    @State private var trainingDraft = TargetDraft(dayType: .training)
    @State private var restDraft = TargetDraft(dayType: .rest)

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $profileDraft.displayName)
                TextField("Email", text: $profileDraft.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                Picker("Sex", selection: $profileDraft.sex) {
                    ForEach(Sex.allCases) { sex in
                        Text(sex.rawValue.capitalized).tag(sex)
                    }
                }
                TextField("Age", value: $profileDraft.age, format: .number)
                    .keyboardType(.numberPad)
                numberField("Height", value: $profileDraft.heightCm, unit: "cm")
                numberField("Weight", value: $profileDraft.currentWeightKg, unit: "kg")
                numberField("Activity factor", value: $profileDraft.activityFactor)
                numberField("Training exercise", value: $profileDraft.trainingExerciseKcal, unit: "kcal")
                TextField("Timezone", text: $profileDraft.timezone)
                    .textInputAutocapitalization(.never)

                LabeledContent("BMR", value: "\(profileDraft.bmr.formatted(.number.precision(.fractionLength(0)))) kcal")

                Button("Save profile") {
                    Task { await store.updateProfile(profileDraft.patchRequest) }
                }
                .disabled(!profileDraft.isValid)
            }
            .accessibilityIdentifier("settings.profile")

            Section("Targets") {
                TargetEditor(draft: $trainingDraft) {
                    Task { await store.updateTarget(dayType: .training, patch: trainingDraft.patchRequest) }
                }

                TargetEditor(draft: $restDraft) {
                    Task { await store.updateTarget(dayType: .rest, patch: restDraft.patchRequest) }
                }
            }

            Section("Session") {
                LabeledContent("Auth", value: auth.statusText)
                LabeledContent("API", value: auth.configuration.apiBaseURL.host() ?? "Unknown")

                if auth.requiresAuthentication {
                    Button(auth.isAuthenticated ? "Reauthenticate" : "Sign in") {
                        Task { await auth.login() }
                    }
                    .disabled(auth.isBusy)

                    if auth.isAuthenticated {
                        Button("Logout", role: .destructive) {
                            Task { await auth.logout() }
                        }
                    }
                }

                if let message = auth.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                }

                Link("Export JSON", destination: auth.configuration.exportURL)
            }
        }
        .navigationTitle("Settings")
        .task {
            if store.profile == nil || store.targets.isEmpty {
                await store.load()
            }
            syncDrafts()
        }
        .onChange(of: store.profile) { _, _ in
            syncProfileDraft()
        }
        .onChange(of: store.targets) { _, _ in
            syncTargetDrafts()
        }
    }

    private func syncDrafts() {
        syncProfileDraft()
        syncTargetDrafts()
    }

    private func syncProfileDraft() {
        if let profile = store.profile {
            profileDraft = ProfileDraft(profile: profile)
        }
    }

    private func syncTargetDrafts() {
        for target in store.targets {
            switch target.dayType {
            case .training:
                trainingDraft = TargetDraft(target: target)
            case .rest:
                restDraft = TargetDraft(target: target)
            }
        }
    }

    private func numberField(
        _ title: String,
        value: Binding<Double>,
        unit: String? = nil
    ) -> some View {
        HStack {
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
            if let unit {
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TargetEditor: View {
    @Binding var draft: TargetDraft
    let onSave: () -> Void

    var body: some View {
        DisclosureGroup(draft.dayType.title) {
            numberField("Burn", value: $draft.burnKcal, unit: "kcal")
            numberField("Intake", value: $draft.intakeKcal, unit: "kcal")
            numberField("Deficit", value: $draft.deficitKcal, unit: "kcal")
            numberField("Carbs", value: $draft.carbsG, unit: "g")
            numberField("Protein", value: $draft.proteinG, unit: "g")
            numberField("Fat", value: $draft.fatG, unit: "g")
            numberField("Water", value: $draft.waterMl, unit: "ml")
            Button("Save \(draft.dayType.title.lowercased()) target", action: onSave)
                .disabled(!draft.isValid)
        }
    }

    private func numberField(
        _ title: String,
        value: Binding<Double>,
        unit: String
    ) -> some View {
        HStack {
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ProfileDraft: Equatable {
    var displayName = ""
    var email = ""
    var sex: Sex = .male
    var age = 1
    var heightCm: Double = 1
    var currentWeightKg: Double = 1
    var timezone = "America/Chicago"
    var activityFactor: Double = 1.2
    var trainingExerciseKcal: Double = 0

    init() {}

    init(profile: Profile) {
        displayName = profile.displayName
        email = profile.email
        sex = profile.sex
        age = profile.age
        heightCm = profile.heightCm
        currentWeightKg = profile.currentWeightKg
        timezone = profile.timezone
        activityFactor = profile.activityFactor
        trainingExerciseKcal = profile.trainingExerciseKcal
    }

    var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            age > 0 &&
            heightCm > 0 &&
            currentWeightKg > 0 &&
            activityFactor > 0 &&
            trainingExerciseKcal >= 0 &&
            !timezone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var bmr: Double {
        NutritionCalculations.bmr(
            ProfileAssumptions(
                sex: sex,
                age: age,
                heightCm: heightCm,
                currentWeightKg: currentWeightKg,
                activityFactor: activityFactor,
                trainingExerciseKcal: trainingExerciseKcal
            )
        )
    }

    var patchRequest: ProfilePatchRequest {
        ProfilePatchRequest(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            sex: sex,
            age: age,
            heightCm: heightCm,
            currentWeightKg: currentWeightKg,
            timezone: timezone.trimmingCharacters(in: .whitespacesAndNewlines),
            activityFactor: activityFactor,
            trainingExerciseKcal: trainingExerciseKcal
        )
    }
}

private struct TargetDraft: Equatable {
    var dayType: DayType
    var burnKcal: Double = 0
    var intakeKcal: Double = 0
    var deficitKcal: Double = 0
    var carbsG: Double = 0
    var proteinG: Double = 0
    var fatG: Double = 0
    var waterMl: Double = 0

    init(dayType: DayType) {
        self.dayType = dayType
    }

    init(target: DailyTarget) {
        dayType = target.dayType
        burnKcal = target.burnKcal
        intakeKcal = target.intakeKcal
        deficitKcal = target.deficitKcal
        carbsG = target.carbsG
        proteinG = target.proteinG
        fatG = target.fatG
        waterMl = target.waterMl
    }

    var isValid: Bool {
        burnKcal >= 0 &&
            intakeKcal >= 0 &&
            carbsG >= 0 &&
            proteinG >= 0 &&
            fatG >= 0 &&
            waterMl >= 0
    }

    var patchRequest: TargetPatchRequest {
        TargetPatchRequest(
            burnKcal: burnKcal,
            intakeKcal: intakeKcal,
            deficitKcal: deficitKcal,
            carbsG: carbsG,
            proteinG: proteinG,
            fatG: fatG,
            waterMl: waterMl
        )
    }
}

#Preview("Settings") {
    let environment = AppEnvironment()
    NavigationStack {
        SettingsView()
            .environment(environment.auth)
            .environment(AppStore.previewLoaded)
    }
}
