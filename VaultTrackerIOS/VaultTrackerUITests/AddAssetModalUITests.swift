//
//  AddAssetModalUITests.swift
//  VaultTrackerUITests
//

import XCTest

final class AddAssetModalUITests: BaseTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = launchApp()
        _ = loginWithDebug(app: app)
    }

    func test_givenModal_whenOpened_thenSaveButtonIsDisabled() {
        let modal = HomePage(app: app).tapAddTransaction().waitForScreen()
        XCTAssertFalse(modal.saveButton.isEnabled)
        _ = modal.close()
    }

    func test_givenModal_whenCloseButtonTapped_thenModalIsDismissed() {
        let home = HomePage(app: app)
        let modal = home.tapAddTransaction().waitForScreen()
        XCTAssertTrue(modal.closeButton.exists)
        _ = modal.close()
        let close = app.identified("closeButton")
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter().wait(for: [dismissed], timeout: 5), .completed)
    }

    func test_givenCashCategory_whenCategorySelected_thenSymbolAndQuantityFieldsHidden() {
        let modal = HomePage(app: app).tapAddTransaction().waitForScreen()
        modal.selectCategory("Cash")
        XCTAssertFalse(modal.symbolField.exists)
        XCTAssertFalse(modal.quantityField.exists)
        _ = modal.close()
    }

    func test_givenCryptoCategory_whenCategorySelected_thenSymbolAndQuantityFieldsVisible() {
        let modal = HomePage(app: app).tapAddTransaction().waitForScreen()
        modal.selectCategory("Crypto")
        XCTAssertTrue(modal.symbolField.waitForExistence(timeout: 5))
        XCTAssertTrue(modal.quantityField.exists)
        XCTAssertTrue(modal.pricePerUnitField.exists)
        _ = modal.close()
    }

    func test_givenCashForm_whenAllRequiredFieldsFilled_thenSaveButtonEnabled() {
        let modal = HomePage(app: app).tapAddTransaction().waitForScreen()
        modal.selectCategory("Cash")
        modal.enterAccountName("UITest Account")
        modal.enterAssetName("UITest Cash")
        modal.enterAmount("100")
        XCTAssertTrue(modal.saveButton.isEnabled)
        _ = modal.close()
    }

    func test_givenCompletedCashForm_whenSaved_thenModalIsDismissed() {
        let modal = HomePage(app: app).tapAddTransaction().waitForScreen()
        modal.selectCategory("Cash")
        modal.enterAccountName("UITest Account")
        modal.enterAssetName("UITest Cash Save")
        modal.enterAmount("50")
        XCTAssertTrue(modal.saveButton.isEnabled)
        _ = modal.save().waitForLoad()
        let close = app.identified("closeButton")
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter().wait(for: [dismissed], timeout: 20), .completed)
    }
}
