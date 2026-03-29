//
//  ProfileTabUITests.swift
//  VaultTrackerUITests
//

import XCTest

final class ProfileTabUITests: BaseTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = launchApp()
        _ = loginWithDebug(app: app)
    }

    func test_givenAuthenticated_whenProfileTabTapped_thenSignOutButtonVisible() {
        let profile = HomePage(app: app).tapProfileTab().waitForScreen()
        XCTAssertTrue(profile.signOutButton.exists)
    }

    func test_givenProfileTab_whenSignOutTapped_thenLoginScreenReturns() {
        let login = HomePage(app: app)
            .tapProfileTab()
            .waitForScreen()
            .signOut()
            .waitForScreen(timeout: 10)
        XCTAssertTrue(login.debugLoginButton.exists)
    }
}
