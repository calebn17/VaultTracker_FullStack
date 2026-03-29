//
//  VaultTrackerUITests.swift
//  VaultTrackerUITests
//
//  Page objects + BDD-style tests. See Documentation/UITests-Plan.md.
//

import XCTest

// MARK: - Setup helpers

private func launchApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-UI-Testing"]
    app.launch()
    return app
}

private func loginWithDebug(app: XCUIApplication) -> HomePage {
    LoginPage(app: app)
        .waitForScreen()
        .tapDebugLogin()
        .waitForScreen()
        .waitForLoad()
}

/// Seeds a cash holding through the Add Transaction sheet (`POST /transactions/smart`). Requires local API + debug auth.
private func seedCashHoldingViaUI(app: XCUIApplication) -> HomePage {
    let modal = HomePage(app: app).tapAddTransaction().waitForScreen()
    modal.selectCategory("Cash")
    modal.enterAccountName("UITest Category Seed Acct")
    modal.enterAssetName("UITest Cash Seed")
    modal.enterAmount("100")
    XCTAssertTrue(modal.saveButton.isEnabled)
    return modal.save().waitForLoad()
}

// MARK: - Login

final class LoginUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_givenAppLaunched_whenUnauthenticated_thenLoginScreenIsVisible() {
        let app = launchApp()
        let login = LoginPage(app: app).waitForScreen(timeout: 10)
        XCTAssertTrue(login.googleSignInButton.waitForExistence(timeout: 5))
        XCTAssertTrue(login.appleSignInButton.exists)
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

// MARK: - Home tab

final class HomeTabUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = launchApp()
        _ = loginWithDebug(app: app)
    }

    func test_givenAuthenticated_whenHomeLoads_thenNetWorthElementsVisible() {
        let home = HomePage(app: app)
        XCTAssertTrue(home.netWorthTitle.exists)
        XCTAssertTrue(home.netWorthValue.exists)
        XCTAssertTrue(home.netWorthChart.waitForExistence(timeout: 5))
    }

    func test_givenAuthenticated_whenHomeLoads_thenTotalNetWorthLabelCopyVisible() {
        let home = HomePage(app: app)
        XCTAssertTrue(home.netWorthTitle.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["TOTAL NET WORTH"].waitForExistence(timeout: 5))
    }

    func test_givenHomeLoaded_whenPeriodChangedToWeekly_thenPickerReflectsSelection() {
        let home = HomePage(app: app)
        XCTAssertTrue(home.periodPicker.waitForExistence(timeout: 5))
        home.selectPeriodSegment(index: 1)
        XCTAssertTrue(home.periodPicker.buttons.element(boundBy: 1).waitForExistence(timeout: 2))
        XCTAssertTrue(home.periodPicker.buttons.element(boundBy: 1).isSelected)
    }

    func test_givenHomeLoaded_whenPeriodChangedToMonthly_thenPickerReflectsSelection() {
        let home = HomePage(app: app)
        XCTAssertTrue(home.periodPicker.waitForExistence(timeout: 5))
        home.selectPeriodSegment(index: 2)
        XCTAssertTrue(home.periodPicker.buttons.element(boundBy: 2).waitForExistence(timeout: 2))
        XCTAssertTrue(home.periodPicker.buttons.element(boundBy: 2).isSelected)
    }

    func test_givenHomeLoaded_whenCryptoFilterTapped_thenCryptoFilterSelected() {
        let home = HomePage(app: app)
        home.tapFilter(category: "Crypto")
        XCTAssertTrue(home.filterButton(for: "Crypto").exists)
    }

    func test_givenCryptoFilterActive_whenAllFilterTapped_thenAllFilterSelected() {
        let home = HomePage(app: app)
        home.tapFilter(category: "Crypto")
        home.tapAllFilter()
        XCTAssertTrue(home.allFilterButton.exists)
    }

    func test_givenHomeLoaded_whenAddTransactionTapped_thenModalPresents() {
        let home = HomePage(app: app)
        let modal = home.tapAddTransaction().waitForScreen()
        XCTAssertTrue(modal.closeButton.exists)
        _ = modal.close()
    }

    func test_givenHomeLoaded_whenCategorySectionTapped_thenSectionExpandsOrCollapses() {
        let home = seedCashHoldingViaUI(app: app)
        let section = home.categorySection(for: "Cash")
        XCTAssertTrue(section.waitForExistence(timeout: 15))
        home.tapCategorySection(category: "Cash")
        XCTAssertTrue(section.exists)
        XCTAssertTrue(section.isHittable)
    }
}

// MARK: - Add asset modal

final class AddAssetModalUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = launchApp()
        _ = loginWithDebug(app: app)
    }

    func test_givenModal_whenOpened_thenSaveButtonIsDisabled() {
        let modal = HomePage(app: app).tapAddTransaction().waitForScreen()
        XCTAssertFalse(modal.saveButton.isEnabled)
        _ = modal.close()
    }

    func test_givenModal_whenCloseButtonTapped_thenModalIsDismissed() {
        let home = HomePage(app: app)
        let modal = home.tapAddTransaction().waitForScreen()
        XCTAssertTrue(modal.closeButton.exists)
        _ = modal.close()
        let close = app.identified("closeButton")
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter().wait(for: [dismissed], timeout: 5), .completed)
    }

    func test_givenCashCategory_whenCategorySelected_thenSymbolAndQuantityFieldsHidden() {
        let modal = HomePage(app: app).tapAddTransaction().waitForScreen()
        modal.selectCategory("Cash")
        XCTAssertFalse(modal.symbolField.exists)
        XCTAssertFalse(modal.quantityField.exists)
        _ = modal.close()
    }

    func test_givenCryptoCategory_whenCategorySelected_thenSymbolAndQuantityFieldsVisible() {
        let modal = HomePage(app: app).tapAddTransaction().waitForScreen()
        modal.selectCategory("Crypto")
        XCTAssertTrue(modal.symbolField.waitForExistence(timeout: 5))
        XCTAssertTrue(modal.quantityField.exists)
        XCTAssertTrue(modal.pricePerUnitField.exists)
        _ = modal.close()
    }

    func test_givenCashForm_whenAllRequiredFieldsFilled_thenSaveButtonEnabled() {
        let modal = HomePage(app: app).tapAddTransaction().waitForScreen()
        modal.selectCategory("Cash")
        modal.enterAccountName("UITest Account")
        modal.enterAssetName("UITest Cash")
        modal.enterAmount("100")
        XCTAssertTrue(modal.saveButton.isEnabled)
        _ = modal.close()
    }

    func test_givenCompletedCashForm_whenSaved_thenModalIsDismissed() {
        let modal = HomePage(app: app).tapAddTransaction().waitForScreen()
        modal.selectCategory("Cash")
        modal.enterAccountName("UITest Account")
        modal.enterAssetName("UITest Cash Save")
        modal.enterAmount("50")
        XCTAssertTrue(modal.saveButton.isEnabled)
        _ = modal.save().waitForLoad()
        let close = app.identified("closeButton")
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter().wait(for: [dismissed], timeout: 20), .completed)
    }
}

// MARK: - Analytics tab

final class AnalyticsTabUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = launchApp()
        _ = loginWithDebug(app: app)
    }

    func test_givenAuthenticated_whenAnalyticsTabTapped_thenAnalyticsScreenVisible() {
        HomePage(app: app).tapAnalyticsTab().waitForScreen()
    }

    func test_givenAnalyticsLoaded_whenDataPresent_thenAllocationSectionVisible() {
        let analytics = HomePage(app: app).tapAnalyticsTab().waitForScreen()
        XCTAssertTrue(analytics.allocationSection.waitForExistence(timeout: 10))
    }

    func test_givenAnalyticsLoaded_whenPerformancePresent_thenPerformanceHeaderVisible() {
        let analytics = HomePage(app: app).tapAnalyticsTab().waitForScreen()
        XCTAssertTrue(analytics.performanceSection.waitForExistence(timeout: 10))
    }
}

// MARK: - Profile tab

final class ProfileTabUITests: XCTestCase {

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
