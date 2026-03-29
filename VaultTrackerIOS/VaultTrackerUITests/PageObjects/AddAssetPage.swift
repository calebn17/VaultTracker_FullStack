import XCTest

struct AddAssetPage {
    let app: XCUIApplication

    var closeButton: XCUIElement { app.identified("closeButton") }
    var saveButton: XCUIElement { app.identified("saveButton") }
    var transactionTypePicker: XCUIElement { app.identified("transactionTypePicker") }
    var accountNameField: XCUIElement { app.identified("accountNameField") }
    /// SwiftUI `Picker` in `Form` is often exposed as `otherElements`, not `XCUIElementTypePicker`; identifier is stable.
    var accountTypePicker: XCUIElement { app.identified("accountTypePicker") }
    /// Horizontal category chip strip container (exposes `.isButton` for the first UI-test tap).
    var categoryPicker: XCUIElement { app.identified("categoryPicker") }
    var assetNameField: XCUIElement { app.identified("assetNameField") }
    var symbolField: XCUIElement { app.identified("symbolField") }
    var quantityField: XCUIElement { app.identified("quantityField") }
    var pricePerUnitField: XCUIElement { app.identified("pricePerUnitField") }
    var transactionDatePicker: XCUIElement { app.identified("transactionDatePicker") }

    @discardableResult
    func waitForScreen(timeout: TimeInterval = 5) -> Self {
        _ = closeButton.waitForExistence(timeout: timeout)
        return self
    }

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

    /// Selects a category by visible label — use `AssetCategory.pickerLabel` / `rawValue` (e.g. `Cash`, `Crypto`, `Stocks/ETFs`).
    /// Do not assume `.capitalized` on `rawValue`; it breaks `Stocks/ETFs` → `Stocks/Etfs`.
    /// Form `Picker` options appear as **buttons** in XCTest, not `staticTexts` (labels exist but are not hittable for tap).
    @discardableResult
    func selectCategory(_ category: String) -> Self {
        categoryPicker.tap()
        let option = app.buttons[category].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10), "Category option \(category) should appear")
        option.tap()
        return self
    }

    @discardableResult
    func save() -> HomePage {
        saveButton.tap()
        return HomePage(app: app)
    }
}
