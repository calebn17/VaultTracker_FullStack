import XCTest

struct LoginPage {
    let app: XCUIApplication

    var googleSignInButton: XCUIElement { app.identified("googleSignInButton") }
    var appleSignInButton: XCUIElement { app.identified("appleSignInButton") }
    var debugLoginButton: XCUIElement { app.identified("debugLoginButton") }
    var loadingView: XCUIElement { app.identified("loadingView") }

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
