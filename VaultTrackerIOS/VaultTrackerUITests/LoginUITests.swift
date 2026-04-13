//
//  LoginUITests.swift
//  VaultTrackerUITests
//

import XCTest

final class LoginUITests: BaseTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_givenAppLaunched_whenUnauthenticated_thenLoginScreenIsVisible() {
        let app = launchApp()
        let login = LoginPage(app: app).waitForScreen(timeout: 10)
        XCTAssertTrue(login.googleSignInButton.waitForExistence(timeout: 5))
        XCTAssertTrue(login.debugLoginButton.exists)
    }

    func test_givenLoginScreen_whenDebugLoginTapped_thenHomeTabIsVisible() {
        let app = launchApp()
        let home = LoginPage(app: app)
            .waitForScreen(timeout: 10)
            .tapDebugLogin()
            .waitForScreen()
        XCTAssertTrue(home.netWorthTitle.waitForExistence(timeout: 15))
    }
}
