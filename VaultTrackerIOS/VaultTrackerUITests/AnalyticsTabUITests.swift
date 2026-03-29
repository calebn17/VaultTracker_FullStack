//
//  AnalyticsTabUITests.swift
//  VaultTrackerUITests
//

import XCTest

final class AnalyticsTabUITests: BaseTestCase {

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
