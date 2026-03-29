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

}

