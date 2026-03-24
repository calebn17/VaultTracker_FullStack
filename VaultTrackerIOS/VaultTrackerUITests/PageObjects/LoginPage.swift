import XCTest

struct LoginPage {
    let app: XCUIApplication

    var googleSignInButton: XCUIElement { app.buttons["googleSignInButton"] }
    var appleSignInButton: XCUIElement { app.buttons["appleSignInButton"] }
    var debugLoginButton: XCUIElement { app.buttons["debugLoginButton"] }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Self {
        _ = debugLoginButton.waitForExistence(timeout: timeout)
        return self
    }

    @discardableResult
    func tapDebugLogin() -> HomePage {
        debugLoginButton.tap()
        return HomePage(app: app)
    }
}
