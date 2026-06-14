import Foundation

@MainActor
@Observable
final class AppEnvironment {
    let auth: AuthSessionStore
    let store: AppStore

    init(configuration: AppConfiguration = .fromBundle()) {
        let cookieBox = AccessCookieBox()
        auth = AuthSessionStore(configuration: configuration, cookieBox: cookieBox)
        store = AppStore(
            client: .live(
                baseURL: configuration.apiBaseURL,
                accessCookie: { [cookieBox] in
                    await cookieBox.value()
                }
            )
        )
    }
}

actor AccessCookieBox {
    private var currentValue: String?

    func set(_ value: String?) {
        currentValue = value
    }

    func value() -> String? {
        currentValue
    }
}
