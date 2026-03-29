import XCTest

struct AnalyticsPage {
    let app: XCUIApplication

    /// Root `List` for the Analytics tab (Digital Ledger uses `List` + hidden scroll background).
    var screen: XCUIElement { app.identified("analyticsScreen") }

    var title: XCUIElement { app.navigationBars.firstMatch.staticTexts["Analytics"] }
    var loadingOverlay: XCUIElement { app.identified("analyticsLoadingOverlay") }
    var performanceSection: XCUIElement { app.identified("analyticsPerformanceSection") }
    var allocationSection: XCUIElement { app.identified("analyticsAllocationSection") }
    var errorRow: XCUIElement { app.identified("analyticsErrorRow") }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Self {
        XCTAssertTrue(title.waitForExistence(timeout: timeout))
        return self
    }

    @discardableResult
    func waitForLoad(timeout: TimeInterval = 10) -> Self {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: loadingOverlay)
        _ = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return self
    }

    @discardableResult
    func pullToRefresh() -> Self {
        screen.swipeDown()
        return self
    }

    @discardableResult
    func tapHomeTab() -> HomePage {
        app.tabBars.buttons["Home"].tap()
        return HomePage(app: app)
    }
}
