import XCTest

struct AnalyticsPage {
    let app: XCUIApplication

    /// Prefer `Table` (SwiftUI `List`); fall back to `otherElements` if the runtime maps it differently.
    var screen: XCUIElement {
        let table = app.tables["analyticsScreen"]
        if table.exists { return table }
        return app.otherElements["analyticsScreen"]
    }
    var loadingOverlay: XCUIElement { app.otherElements["analyticsLoadingOverlay"] }
    var performanceSection: XCUIElement { app.otherElements["analyticsPerformanceSection"] }
    var allocationSection: XCUIElement { app.otherElements["analyticsAllocationSection"] }
    var errorRow: XCUIElement { app.staticTexts["analyticsErrorRow"] }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Self {
        let table = app.tables["analyticsScreen"]
        let other = app.otherElements["analyticsScreen"]
        if table.waitForExistence(timeout: timeout) {
            return self
        }
        _ = other.waitForExistence(timeout: timeout)
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
