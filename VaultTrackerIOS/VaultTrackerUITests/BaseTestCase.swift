//
//  BaseTestCase.swift
//  VaultTrackerUITests
//
//  Shared launch/login/seed helpers for UI tests. See Documentation/UITests-Plan.md.
//

import XCTest

class BaseTestCase: XCTestCase {
    func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UI-Testing"]
        app.launch()
        return app
    }

    func loginWithDebug(app: XCUIApplication) -> HomePage {
        LoginPage(app: app)
            .waitForScreen()
            .tapDebugLogin()
            .waitForScreen()
            .waitForLoad()
    }

    /// Seeds a cash holding through the Add Transaction sheet (`POST /transactions/smart`). Requires local API + debug auth.
    func seedCashHoldingViaUI(app: XCUIApplication) -> HomePage {
        let modal = HomePage(app: app).tapAddTransaction().waitForScreen()
        modal.selectCategory("Cash")
        modal.enterAccountName("UITest Category Seed Acct")
        modal.enterAssetName("UITest Cash Seed")
        modal.enterAmount("100")
        XCTAssertTrue(modal.saveButton.isEnabled)
        return modal.save().waitForLoad()
    }

    /// If the user is in a household, runs **Leave household** from Profile and confirms. Returns whether a leave was performed.
    /// Requires local API + debug auth (same as other UI tests that hit the backend).
    func leaveHouseholdIfInHousehold(app: XCUIApplication) -> Bool {
        _ = HomePage(app: app).tapProfileTab()
        let page = HouseholdSettingsPage(app: app).waitForPageLoaded().scrollUntilSectionHittable()
        guard page.leaveButton.exists else { return false }
        page.leaveButton.tap()
        let sheetButton = app.sheets.firstMatch.buttons["Leave"]
        if sheetButton.waitForExistence(timeout: 4) {
            sheetButton.tap()
        } else {
            let fallback = app.buttons["Leave"]
            if fallback.waitForExistence(timeout: 2) {
                fallback.tap()
            }
        }
        _ = page.createButton.waitForExistence(timeout: 20)
        return true
    }

}

