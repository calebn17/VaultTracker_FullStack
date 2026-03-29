//
//  XCUIApplication+Identified.swift
//  VaultTrackerUITests
//
//  SwiftUI often maps `accessibilityIdentifier` to non-obvious element types; querying by
//  identifier avoids brittle `staticTexts["id"]` / `otherElements["id"]` mismatches.
//

import XCTest

extension XCUIApplication {
    /// First descendant whose accessibility identifier equals `identifier`.
    func identified(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", identifier))
            .firstMatch
    }
}
