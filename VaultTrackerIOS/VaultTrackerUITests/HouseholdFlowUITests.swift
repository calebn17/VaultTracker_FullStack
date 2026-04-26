//
//  HouseholdFlowUITests.swift
//  VaultTrackerUITests
//
//  Household card on Profile + Household/Just Me on Home. Requires the API (e.g. local FastAPI)
//  and debug auth, same as other UI tests in this target.
//

import XCTest

final class HouseholdFlowUITests: BaseTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = launchApp()
        _ = loginWithDebug(app: app)
    }

    func test_profile_householdHeaderAndSectionVisible() {
        _ = HomePage(app: app).tapProfileTab()
        let page = HouseholdSettingsPage(app: app).waitForPageLoaded().scrollUntilSectionHittable()
        XCTAssertTrue(page.header.exists)
    }

    func test_createHousehold_showsModePickerOnHome_andLeaveCleansUp() {
        _ = leaveHouseholdIfInHousehold(app: app)

        _ = HomePage(app: app).tapProfileTab()
        let page = HouseholdSettingsPage(app: app).waitForPageLoaded().scrollUntilSectionHittable()
        XCTAssertTrue(page.createButton.waitForExistence(timeout: 5))
        page.createButton.tap()
        XCTAssertTrue(page.leaveButton.waitForExistence(timeout: 25), "POST /households should succeed with local API")

        _ = HomePage(app: app).tapHomeTab().waitForScreen().waitForLoad()
        let home = HomePage(app: app)
        XCTAssertTrue(home.householdModePicker.waitForExistence(timeout: 15))
        XCTAssertTrue(home.householdModePicker.buttons["Household"].exists)
        XCTAssertTrue(home.householdModePicker.buttons["Just Me"].exists)

        _ = leaveHouseholdIfInHousehold(app: app)
        _ = HomePage(app: app).tapHomeTab().waitForScreen().waitForLoad()
        let soloHome = HomePage(app: app)
        XCTAssertTrue(soloHome.householdModePicker.waitForNonExistence(timeout: 12))
    }

    func test_householdMemberSection_expandedContentToggles() {
        _ = leaveHouseholdIfInHousehold(app: app)

        _ = HomePage(app: app).tapProfileTab()
        let page = HouseholdSettingsPage(app: app).waitForPageLoaded().scrollUntilSectionHittable()
        page.createButton.tap()
        XCTAssertTrue(page.leaveButton.waitForExistence(timeout: 25))

        _ = HomePage(app: app).tapHomeTab().waitForScreen().waitForLoad()
        let home = HomePage(app: app)
        XCTAssertTrue(home.householdModePicker.waitForExistence(timeout: 12))
        _ = home.scrollUntilHittable(home.anyHouseholdMemberSection)
        XCTAssertTrue(home.anyHouseholdMemberSection.waitForExistence(timeout: 8))

        let chevronRightImage = app.images["chevron.right"].firstMatch
        let chevronDownImage = app.images["chevron.down"].firstMatch
        XCTAssertTrue(chevronRightImage.waitForExistence(timeout: 2), "Member section should start collapsed")

        home.anyHouseholdMemberSection.tap()
        XCTAssertTrue(chevronDownImage.waitForExistence(timeout: 2), "Member section should be expanded")

        home.anyHouseholdMemberSection.tap()
        XCTAssertTrue(chevronRightImage.waitForExistence(timeout: 2), "Member section should be collapsed again")

        _ = leaveHouseholdIfInHousehold(app: app)
    }
}

// MARK: - XCUIElement

private extension XCUIElement {
    /// Polls until the element is gone or the timeout elapses. Returns `true` if not present.
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return !exists
    }
}
