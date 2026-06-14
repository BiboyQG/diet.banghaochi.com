import SwiftUI

@MainActor
struct LoginView: View {
    @Environment(AuthSessionStore.self) private var auth

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandLeaf.opacity(0.16), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                VStack(spacing: 18) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 76)
                        .background(
                            LinearGradient(colors: [.brandLeaf, .brandDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .shadow(color: .brand.opacity(0.3), radius: 16, y: 8)

                    VStack(spacing: 8) {
                        Text("Diet Tracker")
                            .font(.largeTitle.weight(.bold))
                        Text("Your daily diet command center. Sign in with Cloudflare Access to reach the protected API.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }

                VStack(spacing: 14) {
                    Button {
                        Task { await auth.login() }
                    } label: {
                        Label(auth.isBusy ? "Signing in…" : "Sign in", systemImage: "person.badge.key.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.brand)
                    .disabled(auth.isBusy)

                    if let message = auth.errorMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Label("Secured by Cloudflare Access", systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06))
                )

                Spacer()
                Spacer()
            }
            .frame(maxWidth: 420)
            .padding(24)
        }
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
