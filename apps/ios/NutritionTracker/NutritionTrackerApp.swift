import SwiftUI

@main
struct NutritionTrackerApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(environment.auth)
                .environment(environment.store)
                .tint(.brand)
        }
    }
}
