import AuthenticationServices
import Foundation
import Security
import SwiftUI
import UIKit

struct AppConfiguration: Equatable, Sendable {
    var apiBaseURL: URL
    var accessLoginURL: URL
    var accessCallbackScheme: String

    var requiresAuthentication: Bool {
        guard let host = apiBaseURL.host()?.lowercased() else { return true }
        return !(host == "localhost" || host == "127.0.0.1" || host == "::1")
    }

    var exportURL: URL {
        URL(string: "export.json", relativeTo: apiBaseURL)!
    }

    static func fromBundle(_ bundle: Bundle = .main) -> AppConfiguration {
        let apiBase = bundle.stringValue(
            for: "API_BASE_URL",
            fallback: "http://localhost:8787/api/v1/"
        )
        let login = bundle.stringValue(
            for: "ACCESS_LOGIN_URL",
            fallback: "https://diet.banghaochi.com/auth/ios-callback"
        )
        let scheme = bundle.stringValue(
            for: "ACCESS_CALLBACK_SCHEME",
            fallback: "diettracker"
        )

        return AppConfiguration(
            apiBaseURL: URL(string: apiBase.withTrailingSlash)!,
            accessLoginURL: URL(string: login)!,
            accessCallbackScheme: scheme
        )
    }
}

struct AuthSession: Codable, Equatable, Sendable {
    var accessCookie: String?
    var authenticatedAt: Date
    var expiresAt: Date

    func isValid(now: Date = Date()) -> Bool {
        expiresAt > now
    }
}

struct AuthSessionStorage: Sendable {
    var load: @Sendable () throws -> AuthSession?
    var save: @Sendable (AuthSession) throws -> Void
    var clear: @Sendable () throws -> Void

    static let keychain = AuthSessionStorage(
        load: {
            try KeychainAuthSessionStorage.load()
        },
        save: { session in
            try KeychainAuthSessionStorage.save(session)
        },
        clear: {
            try KeychainAuthSessionStorage.clear()
        }
    )
}

struct AccessCookie: Equatable, Sendable {
    var value: String
    var expiresAt: Date?

    static func fromCallbackURL(_ url: URL) -> AccessCookie? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let value = components.queryItems?.first(where: { $0.name == "cf_authorization" })?.value,
            !value.isEmpty
        else {
            return nil
        }

        let expiresAt = components.queryItems?
            .first(where: { $0.name == "expires_at" })?
            .value
            .flatMap(parseCallbackDate)
        return AccessCookie(value: value, expiresAt: expiresAt)
    }

    private static func parseCallbackDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

struct AccessCookieReader: Sendable {
    var read: @Sendable (URL) -> AccessCookie?
    var clear: @Sendable (URL) -> Void

    static let live = AccessCookieReader(
        read: { url in
            HTTPCookieStorage.shared.cookies(for: url)?
                .first { $0.name == "CF_Authorization" }
                .map { AccessCookie(value: $0.value, expiresAt: $0.expiresDate) }
        },
        clear: { url in
            HTTPCookieStorage.shared.cookies(for: url)?
                .filter { $0.name.hasPrefix("CF_") }
                .forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        }
    )
}

struct WebAuthenticationClient: Sendable {
    var authenticate: @MainActor @Sendable (URL, String) async throws -> URL

    static let live = WebAuthenticationClient { url, callbackScheme in
        try await SystemWebAuthenticator().authenticate(
            url: url,
            callbackScheme: callbackScheme
        )
    }
}

@MainActor
@Observable
final class AuthSessionStore {
    enum State: Equatable {
        case checking
        case unauthenticated
        case authenticated(AuthSession)
        case failed(String)
    }

    let configuration: AppConfiguration
    private(set) var state: State = .checking

    private let storage: AuthSessionStorage
    private let authenticator: WebAuthenticationClient
    private let cookieReader: AccessCookieReader
    private let cookieBox: AccessCookieBox
    private let now: () -> Date

    init(
        configuration: AppConfiguration,
        storage: AuthSessionStorage = .keychain,
        authenticator: WebAuthenticationClient = .live,
        cookieReader: AccessCookieReader = .live,
        cookieBox: AccessCookieBox = AccessCookieBox(),
        now: @escaping () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.storage = storage
        self.authenticator = authenticator
        self.cookieReader = cookieReader
        self.cookieBox = cookieBox
        self.now = now
    }

    var requiresAuthentication: Bool {
        configuration.requiresAuthentication
    }

    var isAuthenticated: Bool {
        guard requiresAuthentication else { return true }
        guard case .authenticated(let session) = state else { return false }
        return hasUsableSession(session)
    }

    var accessCookie: String? {
        guard case .authenticated(let session) = state, hasUsableSession(session) else {
            return nil
        }
        return session.accessCookie
    }

    var statusText: String {
        guard requiresAuthentication else { return "Local API" }
        switch state {
        case .checking:
            return "Checking"
        case .unauthenticated:
            return "Signed out"
        case .authenticated(let session):
            return session.isValid(now: now()) ? "Signed in" : "Expired"
        case .failed:
            return "Needs attention"
        }
    }

    var isBusy: Bool {
        state == .checking
    }

    var errorMessage: String? {
        guard case .failed(let message) = state else { return nil }
        return message
    }

    func restore() async {
        do {
            guard let session = try storage.load(), hasUsableSession(session) else {
                try? storage.clear()
                state = .unauthenticated
                await cookieBox.set(nil)
                return
            }
            state = .authenticated(session)
            await cookieBox.set(session.accessCookie)
        } catch {
            state = .failed(error.localizedDescription)
            await cookieBox.set(nil)
        }
    }

    func login() async {
        state = .checking
        do {
            let callbackURL = try await authenticator.authenticate(
                configuration.accessLoginURL,
                configuration.accessCallbackScheme
            )
            let cookie =
                AccessCookie.fromCallbackURL(callbackURL)
                ?? cookieReader.read(configuration.apiBaseURL)
            guard let cookie else {
                throw AuthError.missingAccessCookie
            }
            let session = AuthSession(
                accessCookie: cookie.value,
                authenticatedAt: now(),
                expiresAt: cookie.expiresAt ?? now().addingTimeInterval(60 * 60 * 24)
            )
            try storage.save(session)
            state = .authenticated(session)
            await cookieBox.set(session.accessCookie)
        } catch {
            state = .failed(error.localizedDescription)
            await cookieBox.set(nil)
        }
    }

    func logout() async {
        do {
            try storage.clear()
        } catch {
            state = .failed(error.localizedDescription)
            await cookieBox.set(nil)
            return
        }
        cookieReader.clear(configuration.apiBaseURL)
        state = .unauthenticated
        await cookieBox.set(nil)
    }

    private func hasUsableSession(_ session: AuthSession) -> Bool {
        guard session.isValid(now: now()) else { return false }
        guard requiresAuthentication else { return true }
        return session.accessCookie?.isEmpty == false
    }
}

enum AuthError: LocalizedError, Equatable {
    case loginCouldNotStart
    case loginCancelled
    case missingCallback
    case missingAccessCookie
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .loginCouldNotStart:
            return "Could not start Cloudflare Access login."
        case .loginCancelled:
            return "Cloudflare Access login was cancelled."
        case .missingCallback:
            return "Cloudflare Access login did not return to the app."
        case .missingAccessCookie:
            return "Cloudflare Access login did not return an API session."
        case .keychain(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

@MainActor
private final class SystemWebAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func authenticate(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                self.session = nil
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    continuation.resume(throwing: AuthError.loginCancelled)
                } else {
                    continuation.resume(throwing: error ?? AuthError.missingCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session

            if !session.start() {
                self.session = nil
                continuation.resume(throwing: AuthError.loginCouldNotStart)
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private enum KeychainAuthSessionStorage {
    static let service = "com.banghaochi.diet.auth"
    static let account = "cloudflare-access"

    static func load() throws -> AuthSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AuthError.keychain(status)
        }
        return try JSONDecoder().decode(AuthSession.self, from: data)
    }

    static func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        var query = baseQuery
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw AuthError.keychain(addStatus)
            }
        } else if status != errSecSuccess {
            throw AuthError.keychain(status)
        }
    }

    static func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthError.keychain(status)
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}

private extension Bundle {
    func stringValue(for key: String, fallback: String) -> String {
        object(forInfoDictionaryKey: key) as? String ?? fallback
    }
}

private extension String {
    var withTrailingSlash: String {
        hasSuffix("/") ? self : "\(self)/"
    }
}
