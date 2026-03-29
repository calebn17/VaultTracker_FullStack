# Plan: Rewrite VaultTracker UI Tests — Page Objects + BDD

## Context

The iOS app has grown significantly since the existing UI tests were written. Three phases have been added since the last tests were meaningful: Analytics tab (new), period picker on the Home chart (Daily/Weekly/Monthly), and Refresh Prices toolbar button. The existing `VaultTrackerUITests.swift` uses raw element access with no page-object abstraction and no BDD naming convention.

This plan rewrites the UI test layer from scratch with:
- **Page Objects** — one struct per screen, encapsulating element queries and actions
- **BDD naming** — `test_given<State>_when<Action>_then<Outcome>()` for every test method
- Condition-based waiting (`waitForExistence`) everywhere — no `sleep()`
- Coverage of all three tabs + login + modal

---

## Critical Files

### Read-only (understand existing state)
- `VaultTrackerUITests/VaultTrackerUITests.swift` — existing tests (replace, don't extend)
- `VaultTrackerUITests/VaultTrackerUITestsLaunchTests.swift` — keep as-is
- `VaultTracker/Analytics/AnalyticsView.swift` — needs accessibility IDs added

### Files to create
- `VaultTrackerUITests/PageObjects/LoginPage.swift`
- `VaultTrackerUITests/PageObjects/HomePage.swift`
- `VaultTrackerUITests/PageObjects/AddAssetPage.swift`
- `VaultTrackerUITests/PageObjects/AnalyticsPage.swift`
- `VaultTrackerUITests/PageObjects/ProfilePage.swift`
- `VaultTrackerUITests/VaultTrackerUITests.swift` — full rewrite

### Files to modify
- `VaultTracker/Analytics/AnalyticsView.swift` — add missing accessibility identifiers

---

## Step 1 — Add Missing Accessibility Identifiers to AnalyticsView

Read `VaultTracker/Analytics/AnalyticsView.swift` in full, then add:

| Identifier | Element | Notes |
|---|---|---|
| `analyticsScreen` | outermost `List` or container `View` | Used to confirm tab navigation landed |
| `analyticsLoadingOverlay` | the `.ultraThinMaterial` overlay `Rectangle` | Lets tests wait for load to finish |
| `analyticsPerformanceSection` | the `Section` with performance rows | Conditional — only shown when `performance != nil` |
| `analyticsAllocationSection` | the `Section` with allocation rows | Always present when data loads |
| `analyticsErrorRow` | the error `Text` inside the error `Section` | Only present on error |

Apply `.accessibilityIdentifier("…")` modifiers in SwiftUI exactly as done in `HomeView.swift`. Do not add identifiers to individual performance metric rows — the section identifiers are sufficient for UI tests.

---

## Step 2 — Create PageObjects Folder and Page Object Files

Create folder `VaultTrackerUITests/PageObjects/` (it doesn't exist yet).

### 2a. `LoginPage.swift`

```swift
import XCTest

struct LoginPage {
    let app: XCUIApplication

    // Elements
    var googleSignInButton: XCUIElement { app.buttons["googleSignInButton"] }
    var appleSignInButton: XCUIElement  { app.buttons["appleSignInButton"] }
    var debugLoginButton: XCUIElement   { app.buttons["debugLoginButton"] }

    // Waits for login screen to be visible
    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Self {
        _ = debugLoginButton.waitForExistence(timeout: timeout)
        return self
    }

    // Actions — returns the destination page
    @discardableResult
    func tapDebugLogin() -> HomePage {
        debugLoginButton.tap()
        return HomePage(app: app)
    }
}
```

### 2b. `HomePage.swift`

```swift
import XCTest

struct HomePage {
    let app: XCUIApplication

    // Elements
    var netWorthTitle: XCUIElement        { app.staticTexts["netWorthTitleText"] }
    var netWorthValue: XCUIElement        { app.staticTexts["netWorthValueText"] }
    var netWorthChart: XCUIElement        { app.otherElements["netWorthChart"] }
    var periodPicker: XCUIElement         { app.segmentedControls["netWorthPeriodPicker"] }
    var assetBreakdownBar: XCUIElement    { app.otherElements["assetBreakdownBar"] }
    var addTransactionButton: XCUIElement { app.buttons["addTransactionButton"] }
    var refreshPricesButton: XCUIElement  { app.buttons["refreshPricesButton"] }
    var clearDataButton: XCUIElement      { app.buttons["clearDataButton"] }
    var loadingOverlay: XCUIElement       { app.otherElements["loadingOverlay"] }
    var errorBanner: XCUIElement          { app.otherElements["errorBanner"] }
    var dismissErrorButton: XCUIElement   { app.buttons["dismissErrorButton"] }
    var allFilterButton: XCUIElement      { app.buttons["filterAllButton"] }

    func filterButton(for category: String) -> XCUIElement {
        app.buttons["filterButton_\(category)"]
    }
    func categorySection(for category: String) -> XCUIElement {
        app.otherElements["categorySection_\(category)"]
    }

    // Waits for dashboard to be visible after login
    @discardableResult
    func waitForScreen(timeout: TimeInterval = 10) -> Self {
        _ = netWorthTitle.waitForExistence(timeout: timeout)
        return self
    }

    // Waits for loading overlay to disappear
    @discardableResult
    func waitForLoad(timeout: TimeInterval = 10) -> Self {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: loadingOverlay)
        _ = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return self
    }

    // Actions
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
        refreshPricesButton.tap()
        return self
    }

    @discardableResult
    func tapCategorySection(category: String) -> Self {
        categorySection(for: category).tap()
        return self
    }
}
```

### 2c. `AddAssetPage.swift`

```swift
import XCTest

struct AddAssetPage {
    let app: XCUIApplication

    // Elements
    var closeButton: XCUIElement          { app.buttons["closeButton"] }
    var saveButton: XCUIElement           { app.buttons["saveButton"] }
    var transactionTypePicker: XCUIElement{ app.segmentedControls["transactionTypePicker"] }
    var accountNameField: XCUIElement     { app.textFields["accountNameField"] }
    var accountTypePicker: XCUIElement    { app.pickers["accountTypePicker"] }
    var categoryPicker: XCUIElement       { app.pickers["categoryPicker"] }
    var assetNameField: XCUIElement       { app.textFields["assetNameField"] }
    var symbolField: XCUIElement          { app.textFields["symbolField"] }
    var quantityField: XCUIElement        { app.textFields["quantityField"] }
    var pricePerUnitField: XCUIElement    { app.textFields["pricePerUnitField"] }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Self {
        _ = closeButton.waitForExistence(timeout: timeout)
        return self
    }

    // Actions
    @discardableResult
    func close() -> HomePage {
        closeButton.tap()
        return HomePage(app: app)
    }

    @discardableResult
    func enterAccountName(_ name: String) -> Self {
        accountNameField.tap()
        accountNameField.typeText(name)
        return self
    }

    @discardableResult
    func enterAssetName(_ name: String) -> Self {
        assetNameField.tap()
        assetNameField.typeText(name)
        return self
    }

    @discardableResult
    func enterAmount(_ amount: String) -> Self {
        pricePerUnitField.tap()
        pricePerUnitField.typeText(amount)
        return self
    }

    @discardableResult
    func enterSymbol(_ symbol: String) -> Self {
        symbolField.tap()
        symbolField.typeText(symbol)
        return self
    }

    @discardableResult
    func enterQuantity(_ qty: String) -> Self {
        quantityField.tap()
        quantityField.typeText(qty)
        return self
    }

    @discardableResult
    func selectCategory(_ category: String) -> Self {
        categoryPicker.tap()
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: category)
        return self
    }

    @discardableResult
    func save() -> HomePage {
        saveButton.tap()
        return HomePage(app: app)
    }
}
```

### 2d. `AnalyticsPage.swift`

```swift
import XCTest

struct AnalyticsPage {
    let app: XCUIApplication

    // Elements
    var screen: XCUIElement             { app.otherElements["analyticsScreen"] }
    var loadingOverlay: XCUIElement     { app.otherElements["analyticsLoadingOverlay"] }
    var performanceSection: XCUIElement { app.otherElements["analyticsPerformanceSection"] }
    var allocationSection: XCUIElement  { app.otherElements["analyticsAllocationSection"] }
    var errorRow: XCUIElement           { app.staticTexts["analyticsErrorRow"] }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Self {
        _ = screen.waitForExistence(timeout: timeout)
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
```

### 2e. `ProfilePage.swift`

```swift
import XCTest

struct ProfilePage {
    let app: XCUIApplication

    var signOutButton: XCUIElement { app.buttons["signOutButton"] }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Self {
        _ = signOutButton.waitForExistence(timeout: timeout)
        return self
    }

    @discardableResult
    func signOut() -> LoginPage {
        signOutButton.tap()
        return LoginPage(app: app)
    }
}
```

---

## Step 3 — Rewrite VaultTrackerUITests.swift

Replace the entire content of `VaultTrackerUITests/VaultTrackerUITests.swift`. Use `XCTestCase` subclasses (one per feature area). `@MainActor` is not needed — UI tests run on the main thread by default.

### Setup helpers

```swift
private func launchApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-UI-Testing"]
    app.launch()
    return app
}

private func loginWithDebug(app: XCUIApplication) -> HomePage {
    return LoginPage(app: app)
        .waitForScreen()
        .tapDebugLogin()
        .waitForScreen()
}
```

### Test Classes and BDD Scenarios

#### `LoginUITests: XCTestCase`

```
test_givenAppLaunched_whenUnauthenticated_thenLoginScreenIsVisible
  Given: app launched fresh with -UI-Testing
  When:  login screen renders
  Then:  Google, Apple, and Debug Login buttons all exist

test_givenLoginScreen_whenDebugLoginTapped_thenHomeTabIsVisible
  Given: login screen is shown
  When:  user taps Debug Login
  Then:  net worth title label appears in Home tab
```

#### `HomeTabUITests: XCTestCase`

```
test_givenAuthenticated_whenHomeLoads_thenNetWorthElementsVisible
  Given: logged in via debug
  When:  home tab loads
  Then:  net worth title and value labels exist; chart exists

test_givenHomeLoaded_whenPeriodChangedToWeekly_thenPickerReflectsSelection
  Given: home loaded, period picker showing Daily (index 0)
  When:  user taps Weekly segment (index 1)
  Then:  the Weekly segment is selected

test_givenHomeLoaded_whenPeriodChangedToMonthly_thenPickerReflectsSelection
  Given: home loaded, period picker showing Daily
  When:  user taps Monthly segment (index 2)
  Then:  the Monthly segment is selected

test_givenHomeLoaded_whenCryptoFilterTapped_thenCryptoFilterSelected
  Given: home loaded with All filter active
  When:  user taps Crypto filter button
  Then:  Crypto filter button exists and is tappable

test_givenCryptoFilterActive_whenAllFilterTapped_thenAllFilterSelected
  Given: Crypto filter is active
  When:  user taps All filter
  Then:  All filter button exists

test_givenHomeLoaded_whenAddTransactionTapped_thenModalPresents
  Given: home loaded
  When:  user taps the + (Add Transaction) toolbar button
  Then:  modal close button exists (modal is on screen)

test_givenHomeLoaded_whenRefreshPricesTapped_thenButtonTemporarilyDisabled
  Given: home loaded, refresh prices button enabled
  When:  user taps Refresh Prices
  Then:  button is disabled immediately after tap

test_givenHomeLoaded_whenCategorySectionTapped_thenSectionExpandsOrCollapses
  Given: home loaded with category sections visible
  When:  user taps a category section header
  Then:  section element remains accessible after tap
```

#### `AddAssetModalUITests: XCTestCase`

```
test_givenModal_whenOpened_thenSaveButtonIsDisabled
  Given: Add Transaction modal is open
  When:  no fields are filled
  Then:  save button is disabled (isEnabled == false)

test_givenModal_whenCloseButtonTapped_thenModalIsDismissed
  Given: modal open
  When:  close button tapped
  Then:  close button no longer exists

test_givenCashCategory_whenCategorySelected_thenSymbolAndQuantityFieldsHidden
  Given: modal open, Cash category selected
  When:  checking form fields
  Then:  symbolField does NOT exist; quantityField does NOT exist

test_givenCryptoCategory_whenCategorySelected_thenSymbolAndQuantityFieldsVisible
  Given: modal open, Crypto category selected
  When:  checking form fields
  Then:  symbolField exists; quantityField exists; pricePerUnitField exists

test_givenCashForm_whenAllRequiredFieldsFilled_thenSaveButtonEnabled
  Given: modal open, Cash selected
  When:  account name, asset name, and amount are filled
  Then:  save button is enabled (isEnabled == true)

test_givenCompletedCashForm_whenSaved_thenModalIsDismissed
  Given: modal open, valid cash form filled
  When:  save button tapped
  Then:  close button no longer exists (back on home)
```

#### `AnalyticsTabUITests: XCTestCase`

```
test_givenAuthenticated_whenAnalyticsTabTapped_thenAnalyticsScreenVisible
  Given: logged in, on Home tab
  When:  user taps Analytics tab
  Then:  analyticsScreen element exists

test_givenAnalyticsLoaded_whenDataPresent_thenAllocationSectionVisible
  Given: analytics tab loaded, data returned from backend
  When:  loading overlay disappears
  Then:  analyticsAllocationSection exists

test_givenAnalyticsLoaded_whenPulledToRefresh_thenLoadingOverlayAppearsAndDisappears
  Given: analytics screen loaded
  When:  user pulls to refresh
  Then:  loading overlay appears then disappears within timeout
```

#### `ProfileTabUITests: XCTestCase`

```
test_givenAuthenticated_whenProfileTabTapped_thenSignOutButtonVisible
  Given: logged in
  When:  user taps Profile tab
  Then:  sign out button exists

test_givenProfileTab_whenSignOutTapped_thenLoginScreenReturns
  Given: on Profile tab
  When:  sign out button tapped
  Then:  debug login button re-appears (returned to login screen)
```

---

## Step 4 — Verification

1. Build the UI test target (Cmd+U) — confirm 0 compile errors.
2. Run `LoginUITests` — passes without a live backend (debug bypass is local).
3. Run `HomeTabUITests` — requires local backend at `localhost:8000` with `DEBUG_AUTH_ENABLED=true`.
4. Run `AnalyticsTabUITests` — same backend requirement.
5. Run `AddAssetModalUITests` — modal form tests are local-only; the `save` test requires backend.
6. Grep for `sleep(` in new test files — expect zero results.
7. Confirm every test method name starts with `test_given`.

---

## Notes for the Implementing Agent

- **No `sleep()`** — use `waitForExistence(timeout:)` or `XCTNSPredicateExpectation` everywhere.
- **Segmented picker** — SwiftUI `.pickerStyle(.segmented)` renders as `XCUIElementType.segmentedControl`. Tap segments by index: `periodPicker.buttons.element(boundBy: 1).tap()`.
- **Menu picker** — SwiftUI `Picker` (default style) may render as a tappable button that opens a menu, not a wheel. Tap the button, then find the option by label. Inspect with `app.debugDescription` if unsure.
- **Filter button identifiers** — match exactly what's in `.accessibilityIdentifier`, e.g. `"filterButton_Crypto"`, `"filterButton_Stocks/ETFs"`.
- **Tab bar labels** — use `app.tabBars.buttons["Analytics"]` matching the `.tabItem` label string exactly.
- **`continueAfterFailure = false`** — set in every `setUpWithError()`.
- **Analytics IDs** — Step 1 must be done before analytics tests will find any elements. The loading overlay in `AnalyticsView` may be inside a `ZStack` — check the exact view hierarchy before applying the identifier.
- **Launch test** — leave `VaultTrackerUITestsLaunchTests.swift` untouched.
- **Target membership** — after creating files in `PageObjects/`, verify they are added to the `VaultTrackerUITests` target in Xcode (checkmark in File Inspector). Use the Xcode MCP `add_file` tool if available, otherwise add manually.
