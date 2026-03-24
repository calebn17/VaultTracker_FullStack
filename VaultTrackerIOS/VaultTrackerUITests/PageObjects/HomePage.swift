import XCTest

struct HomePage {
    let app: XCUIApplication

    /// Main vertical `ScrollView` (excludes the horizontal filter strip).
    var homeScrollView: XCUIElement { app.scrollViews["homeScrollView"] }

    var netWorthTitle: XCUIElement { app.staticTexts["netWorthTitleText"] }
    var netWorthValue: XCUIElement { app.staticTexts["netWorthValueText"] }
    var netWorthChart: XCUIElement { app.otherElements["netWorthChart"] }
    var periodPicker: XCUIElement { app.segmentedControls["netWorthPeriodPicker"] }
    var assetBreakdownBar: XCUIElement { app.otherElements["assetBreakdownBar"] }
    var addTransactionButton: XCUIElement { app.buttons["addTransactionButton"] }
    var refreshPricesButton: XCUIElement { app.buttons["refreshPricesButton"] }
    var clearDataButton: XCUIElement { app.buttons["clearDataButton"] }
    var loadingOverlay: XCUIElement { app.otherElements["loadingOverlay"] }
    var errorBanner: XCUIElement { app.otherElements["errorBanner"] }
    var dismissErrorButton: XCUIElement { app.buttons["dismissErrorButton"] }
    var allFilterButton: XCUIElement { app.buttons["filterAllButton"] }

    func filterButton(for category: String) -> XCUIElement {
        app.buttons["filterButton_\(category)"]
    }

    func categorySection(for category: String) -> XCUIElement {
        app.staticTexts["categorySection_\(category)"]
    }

    /// Swipes up on the home scroll view until `element` is hittable (on-screen), or `maxSwipes` is reached.
    /// Use for content below the fold (e.g. category rows). Toolbar controls that are already hittable return immediately.
    @discardableResult
    func scrollUntilHittable(_ element: XCUIElement, maxSwipes: Int = 25) -> Self {
        guard homeScrollView.waitForExistence(timeout: 5) else { return self }
        var swipes = 0
        while swipes < maxSwipes {
            if element.exists && element.isHittable { return self }
            homeScrollView.swipeUp()
            swipes += 1
        }
        return self
    }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 10) -> Self {
        _ = netWorthTitle.waitForExistence(timeout: timeout)
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
    func tapAddTransaction() -> AddAssetPage {
        addTransactionButton.tap()
        return AddAssetPage(app: app)
    }

    @discardableResult
    func tapAnalyticsTab() -> AnalyticsPage {
        app.tabBars.buttons["Analytics"].tap()
        return AnalyticsPage(app: app)
    }

    @discardableResult
    func tapProfileTab() -> ProfilePage {
        app.tabBars.buttons["Profile"].tap()
        return ProfilePage(app: app)
    }

    @discardableResult
    func selectPeriodSegment(index: Int) -> Self {
        periodPicker.buttons.element(boundBy: index).tap()
        return self
    }

    @discardableResult
    func tapFilter(category: String) -> Self {
        filterButton(for: category).tap()
        return self
    }

    @discardableResult
    func tapAllFilter() -> Self {
        allFilterButton.tap()
        return self
    }

    @discardableResult
    func tapRefreshPrices() -> Self {
        _ = scrollUntilHittable(refreshPricesButton)
        refreshPricesButton.tap()
        return self
    }

    @discardableResult
    func tapCategorySection(category: String) -> Self {
        let section = categorySection(for: category).firstMatch
        _ = scrollUntilHittable(section)
        section.tap()
        return self
    }
}
