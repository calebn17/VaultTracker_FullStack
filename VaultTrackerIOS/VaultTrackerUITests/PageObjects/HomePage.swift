import XCTest

struct HomePage {
    let app: XCUIApplication

    /// Main vertical `ScrollView` (excludes the horizontal filter strip).
    var homeScrollView: XCUIElement { app.identified("homeScrollView") }

    var netWorthTitle: XCUIElement { app.identified("netWorthTitleText") }
    var netWorthValue: XCUIElement { app.identified("netWorthValueText") }
    var netWorthChart: XCUIElement { app.identified("netWorthChart") }
    var periodPicker: XCUIElement { app.identified("netWorthPeriodPicker") }
    var assetBreakdownBar: XCUIElement { app.identified("assetBreakdownBar") }
    var addTransactionButton: XCUIElement { app.identified("addTransactionButton") }
    var refreshPricesButton: XCUIElement { app.identified("refreshPricesButton") }
    var clearDataButton: XCUIElement { app.identified("clearDataButton") }
    var loadingOverlay: XCUIElement { app.identified("loadingOverlay") }
    var errorBanner: XCUIElement { app.identified("errorBanner") }
    var dismissErrorButton: XCUIElement { app.identified("dismissErrorButton") }
    var allFilterButton: XCUIElement { app.identified("filterAllButton") }

    func filterButton(for category: String) -> XCUIElement {
        app.identified("filterButton_\(category)")
    }

    func categorySection(for category: String) -> XCUIElement {
        app.identified("categorySection_\(category)")
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
    func tapHomeTab() -> HomePage {
        app.tabBars.buttons["Home"].tap()
        return self
    }

    /// Visible when the user is in a household (Household / Just Me scope).
    var householdModePicker: XCUIElement { app.identified("householdModePicker") }

    /// First member card on the home dashboard (identifier prefix `householdMemberSection_`).
    var anyHouseholdMemberSection: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH[c] %@", "householdMemberSection_"))
            .firstMatch
    }

    /// Expanded member body (only exists while expanded). Identifier `householdMemberExpanded_<userId>`.
    var anyHouseholdMemberExpanded: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH[c] %@", "householdMemberExpanded_"))
            .firstMatch
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
        let section = categorySection(for: category)
        _ = scrollUntilHittable(section)
        section.tap()
        return self
    }
}
