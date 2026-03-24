import XCTest

struct ProfilePage {
    let app: XCUIApplication

    var signOutButton: XCUIElement { app.buttons["signOutButton"] }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Self {
        _ = signOutButton.waitForExistence(timeout: timeout)
        return self
    }

    @discardableResult
    func signOut() -> LoginPage {
        signOutButton.tap()
        return LoginPage(app: app)
    }
}
