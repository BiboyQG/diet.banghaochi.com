import SwiftUI

@MainActor
struct LoginView: View {
    @Environment(AuthSessionStore.self) private var auth

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Diet Tracker")
                    .font(.largeTitle.weight(.bold))
                Text("Sign in with Cloudflare Access to reach the protected API.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await auth.login() }
            } label: {
                Label("Sign in", systemImage: "person.badge.key")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(auth.isBusy)

            if let message = auth.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: 420, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
    }
}

#Preview("Login") {
    let configuration = AppConfiguration(
        apiBaseURL: URL(string: "https://diet.banghaochi.com/api/v1/")!,
        accessLoginURL: URL(string: "https://diet.banghaochi.com/auth/ios-callback")!,
        accessCallbackScheme: "diettracker"
    )
    LoginView()
        .environment(AuthSessionStore(configuration: configuration))
}
