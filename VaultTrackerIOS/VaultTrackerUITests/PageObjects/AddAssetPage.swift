import XCTest

struct AddAssetPage {
    let app: XCUIApplication

    var closeButton: XCUIElement { app.buttons["closeButton"] }
    var saveButton: XCUIElement { app.buttons["saveButton"] }
    var transactionTypePicker: XCUIElement { app.segmentedControls["transactionTypePicker"] }
    var accountNameField: XCUIElement { app.textFields["accountNameField"] }
    /// SwiftUI `Picker` in `Form` is exposed as `otherElements`, not `XCUIElementTypePicker`.
    var accountTypePicker: XCUIElement { app.otherElements["accountTypePicker"] }
    var categoryPicker: XCUIElement { app.buttons["categoryPicker"] }
    var assetNameField: XCUIElement { app.textFields["assetNameField"] }
    var symbolField: XCUIElement { app.textFields["symbolField"] }
    var quantityField: XCUIElement { app.textFields["quantityField"] }
    var pricePerUnitField: XCUIElement { app.textFields["pricePerUnitField"] }

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

    /// Selects a category by visible label (e.g. `Cash`, `Crypto`).
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
