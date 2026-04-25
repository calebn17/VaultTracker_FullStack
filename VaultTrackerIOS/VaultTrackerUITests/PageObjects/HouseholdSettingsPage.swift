import XCTest

/// Profile tab: household create / join / invite / leave (`HouseholdSettingsView`).
struct HouseholdSettingsPage {
    let app: XCUIApplication

    var section: XCUIElement { app.identified("householdSettingsSection") }
    var header: XCUIElement { app.identified("householdSettingsHeader") }
    var createButton: XCUIElement { app.identified("householdCreateButton") }
    var joinCodeField: XCUIElement { app.identified("householdJoinCodeField") }
    var joinButton: XCUIElement { app.identified("householdJoinButton") }
    var leaveButton: XCUIElement { app.identified("householdLeaveButton") }
    var generateInviteCodeButton: XCUIElement { app.identified("householdGenerateCodeButton") }

    @discardableResult
    func scrollUntilSectionHittable(maxSwipes: Int = 15) -> Self {
        let scroll = app.scrollViews.firstMatch
        var n = 0
        while n < maxSwipes {
            if section.exists, section.isHittable { return self }
            if scroll.exists {
                scroll.swipeUp()
            } else {
                break
            }
            n += 1
        }
        return self
    }

    @discardableResult
    func waitForSection(timeout: TimeInterval = 12) -> Self {
        _ = section.waitForExistence(timeout: timeout)
        return self
    }
}
