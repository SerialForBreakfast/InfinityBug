//
//  InfinityBugUITests.swift
//  InfinityBugUITests
//
//  Automatically generated focus regression test
//


import XCTest

/// tvOS helper to fetch the currently focused element.
private extension XCUIApplication {
    var focusedIdentifier: String {
        let focused = descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == true"))
            .firstMatch
        return focused.identifier
    }
}

final class InfinityBugUITests: XCTestCase {

    private let remote = XCUIRemote.shared

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Verifies that a right‑swipe from the sidebar lands in the EPG,
    /// and a left‑swipe from the EPG returns to the sidebar.
    func testFocusNavigationSidebarToEPG() throws {

        let app = XCUIApplication()
        // Enable VoiceOver to mimic real accessibility scenario
        app.launchArguments.append("-AppleTVAccessibility")  // private flag but OK in CI
        app.launch()

        // Sidebar should be focused at launch
        XCTAssertEqual(app.focusedIdentifier, "CategoriesCollectionView",
                      "Expected focus in sidebar on launch")

        // Step 1: press Right → expect EPG focus
        print("[TEST] Pressing Right")
        remote.press(.right)
        XCTAssertTrue(waitForFocus("EPGView", app: app),
                      "Right swipe should move focus into the EPG")

        // Step 2: press Left → expect Categories focus again
        print("[TEST] Pressing Left")
        remote.press(.left)
        XCTAssertTrue(waitForFocus("CategoriesCollectionView", app: app),
                      "Left swipe should return focus to the sidebar")
    }

    /// Polls `app.focusedIdentifier` until it matches
    /// `expectedIdentifier` or the timeout elapses.
    private func waitForFocus(_ expectedIdentifier: String,
                              app: XCUIApplication,
                              timeout: TimeInterval = 2.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.focusedIdentifier == expectedIdentifier { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return false
    }
}
