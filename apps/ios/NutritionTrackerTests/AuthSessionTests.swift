import XCTest
@testable import NutritionTracker

@MainActor
final class AuthSessionTests: XCTestCase {
    func testLocalConfigurationDoesNotRequireAuthentication() {
        let store = AuthSessionStore(
            configuration: AppConfiguration(
                apiBaseURL: URL(string: "http://localhost:8787/api/v1/")!,
                accessLoginURL: URL(string: "https://diet.banghaochi.com/auth/ios-callback")!,
                accessCallbackScheme: "diettracker"
            ),
            storage: MemoryAuthStorage().storage,
            authenticator: .mock(),
            cookieReader: .mock(cookie: nil)
        )

        XCTAssertFalse(store.requiresAuthentication)
        XCTAssertTrue(store.isAuthenticated)
    }

    func testLoginStoresCloudflareAccessCookie() async throws {
        let now = Date(timeIntervalSince1970: 100)
        let storage = MemoryAuthStorage()
        let cookieBox = AccessCookieBox()
        let store = AuthSessionStore(
            configuration: .protectedFixture,
            storage: storage.storage,
            authenticator: .mock(),
            cookieReader: .mock(
                cookie: AccessCookie(
                    value: "access-jwt",
                    expiresAt: now.addingTimeInterval(3600)
                )
            ),
            cookieBox: cookieBox,
            now: { now }
        )

        await store.login()

        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.accessCookie, "access-jwt")
        XCTAssertEqual(try storage.load()?.accessCookie, "access-jwt")
        let cookieBoxValue = await cookieBox.value()
        XCTAssertEqual(cookieBoxValue, "access-jwt")
    }

    func testLoginStoresCallbackAccessCookie() async throws {
        let now = Date(timeIntervalSince1970: 100)
        let storage = MemoryAuthStorage()
        let cookieBox = AccessCookieBox()
        let store = AuthSessionStore(
            configuration: .protectedFixture,
            storage: storage.storage,
            authenticator: .mock(
                callbackURL: URL(
                    string: "diettracker://access/callback?cf_authorization=callback-jwt&expires_at=1970-01-01T01:16:40.000Z"
                )!
            ),
            cookieReader: .mock(cookie: nil),
            cookieBox: cookieBox,
            now: { now }
        )

        await store.login()

        XCTAssertTrue(store.isAuthenticated)
        XCTAssertEqual(store.accessCookie, "callback-jwt")
        XCTAssertEqual(try storage.load()?.expiresAt, Date(timeIntervalSince1970: 4600))
        let cookieBoxValue = await cookieBox.value()
        XCTAssertEqual(cookieBoxValue, "callback-jwt")
    }

    func testLoginFailsWithoutAccessCookie() async throws {
        let store = AuthSessionStore(
            configuration: .protectedFixture,
            storage: MemoryAuthStorage().storage,
            authenticator: .mock(),
            cookieReader: .mock(cookie: nil)
        )

        await store.login()

        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNil(store.accessCookie)
        XCTAssertEqual(
            store.errorMessage,
            AuthError.missingAccessCookie.errorDescription
        )
    }

    func testRestoreClearsExpiredSession() async throws {
        let now = Date(timeIntervalSince1970: 100)
        let storage = MemoryAuthStorage(
            session: AuthSession(
                accessCookie: "expired",
                authenticatedAt: now.addingTimeInterval(-7200),
                expiresAt: now.addingTimeInterval(-1)
            )
        )
        let cookieBox = AccessCookieBox()
        let store = AuthSessionStore(
            configuration: .protectedFixture,
            storage: storage.storage,
            authenticator: .mock(),
            cookieReader: .mock(cookie: nil),
            cookieBox: cookieBox,
            now: { now }
        )

        await store.restore()

        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNil(store.accessCookie)
        let cookieBoxValue = await cookieBox.value()
        XCTAssertNil(cookieBoxValue)
    }

    func testRestoreClearsSessionWithoutAccessCookie() async throws {
        let now = Date(timeIntervalSince1970: 100)
        let storage = MemoryAuthStorage(
            session: AuthSession(
                accessCookie: nil,
                authenticatedAt: now,
                expiresAt: now.addingTimeInterval(3600)
            )
        )
        let cookieBox = AccessCookieBox()
        let store = AuthSessionStore(
            configuration: .protectedFixture,
            storage: storage.storage,
            authenticator: .mock(),
            cookieReader: .mock(cookie: nil),
            cookieBox: cookieBox,
            now: { now }
        )

        await store.restore()

        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNil(try storage.load())
        let cookieBoxValue = await cookieBox.value()
        XCTAssertNil(cookieBoxValue)
    }

    func testLogoutClearsSessionAndCookies() async throws {
        let now = Date(timeIntervalSince1970: 100)
        let storage = MemoryAuthStorage(
            session: AuthSession(
                accessCookie: "access-jwt",
                authenticatedAt: now,
                expiresAt: now.addingTimeInterval(3600)
            )
        )
        let cookieReader = MemoryCookieReader(cookie: nil)
        let cookieBox = AccessCookieBox()
        let store = AuthSessionStore(
            configuration: .protectedFixture,
            storage: storage.storage,
            authenticator: .mock(),
            cookieReader: cookieReader.reader,
            cookieBox: cookieBox,
            now: { now }
        )

        await store.restore()
        await store.logout()

        XCTAssertFalse(store.isAuthenticated)
        XCTAssertNil(try storage.load())
        XCTAssertEqual(cookieReader.clearedURL, AppConfiguration.protectedFixture.apiBaseURL)
        let cookieBoxValue = await cookieBox.value()
        XCTAssertNil(cookieBoxValue)
    }
}

private extension AppConfiguration {
    static let protectedFixture = AppConfiguration(
        apiBaseURL: URL(string: "https://diet.banghaochi.com/api/v1/")!,
        accessLoginURL: URL(string: "https://diet.banghaochi.com/auth/ios-callback")!,
        accessCallbackScheme: "diettracker"
    )
}

private extension WebAuthenticationClient {
    static func mock(callbackURL: URL = URL(string: "diettracker://access/callback")!) -> WebAuthenticationClient {
        WebAuthenticationClient { _, _ in callbackURL }
    }
}

private extension AccessCookieReader {
    static func mock(cookie: AccessCookie?) -> AccessCookieReader {
        AccessCookieReader(read: { _ in cookie }, clear: { _ in })
    }
}

private final class MemoryAuthStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var session: AuthSession?

    init(session: AuthSession? = nil) {
        self.session = session
    }

    var storage: AuthSessionStorage {
        AuthSessionStorage(
            load: {
                self.lock.lock()
                defer { self.lock.unlock() }
                return self.session
            },
            save: { session in
                self.lock.lock()
                defer { self.lock.unlock() }
                self.session = session
            },
            clear: {
                self.lock.lock()
                defer { self.lock.unlock() }
                self.session = nil
            }
        )
    }

    func load() throws -> AuthSession? {
        try storage.load()
    }
}

private final class MemoryCookieReader: @unchecked Sendable {
    private let lock = NSLock()
    private var cookie: AccessCookie?
    private var cleared: URL?

    init(cookie: AccessCookie?) {
        self.cookie = cookie
    }

    var clearedURL: URL? {
        lock.lock()
        defer { lock.unlock() }
        return cleared
    }

    var reader: AccessCookieReader {
        AccessCookieReader(
            read: { _ in
                self.lock.lock()
                defer { self.lock.unlock() }
                return self.cookie
            },
            clear: { url in
                self.lock.lock()
                defer { self.lock.unlock() }
                self.cleared = url
            }
        )
    }
}
