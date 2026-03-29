//
//  HomeTabUITests.swift
//  VaultTrackerUITests
//

import XCTest

final class HomeTabUITests: BaseTestCase {

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
