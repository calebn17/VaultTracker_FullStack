import XCTest

struct AnalyticsPage {
    let app: XCUIApplication

    var screen: XCUIElement { app.tables.firstMatch }
    var title: XCUIElement { app.staticTexts["Analytics"] }
    var loadingOverlay: XCUIElement { app.otherElements["analyticsLoadingOverlay"] }
    var performanceSection: XCUIElement { app.otherElements["analyticsPerformanceSection"] }
    var allocationSection: XCUIElement { app.staticTexts["analyticsAllocationSection"].firstMatch }
    var errorRow: XCUIElement { app.staticTexts["analyticsErrorRow"] }

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
