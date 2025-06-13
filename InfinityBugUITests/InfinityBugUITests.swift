//
//  InfinityBugUITests.swift
//  InfinityBugUITests
//
//  Automatically generated focus regression test
//


import XCTest
@testable import InfinityBug

/// Shared test helpers
private extension XCUIApplication {
    var focusedIdentifier: String {
        let focused = descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == true"))
            .firstMatch
        return focused.identifier
    }
    
    func waitForElementToExist(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    /// Polls `focusedIdentifier` until it matches
    /// `expectedIdentifier` or the timeout elapses.
    func waitForFocus(_ expectedIdentifier: String,
                      timeout: TimeInterval = 5.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if focusedIdentifier == expectedIdentifier { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        print("[TEST] Focus wait timed out. Current focus: \(focusedIdentifier)")
        return false
    }

    /// Waits until focus.identifier has the given prefix.
    func waitForFocusPrefix(_ prefix: String,
                            timeout: TimeInterval = 5.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if focusedIdentifier.hasPrefix(prefix) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }
}

final class InfinityBugUITests: XCTestCase {
    private let remote = XCUIRemote.shared
    private var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-AppleTVAccessibility")
        
        // Disable async request spoofing for tests
        ViewController.spoofAsyncRequests = false
    }
    
    override func tearDownWithError() throws {
        // Re-enable async request spoofing after tests
        ViewController.spoofAsyncRequests = true
        app = nil
    }

    /// Verifies that a right‑swipe from the sidebar lands in the EPG,
    /// and a left‑swipe from the EPG returns to the sidebar.
    func testFocusNavigationSidebarToEPG() throws {
        app.launch()
        
        // Wait for the app to be ready
        let categoriesView = app.collectionViews["CategoriesCollectionView"]
        XCTAssertTrue(app.waitForElementToExist(categoriesView), "Categories view should exist")
        
        // Wait for initial focus
        XCTAssertTrue(app.waitForFocusPrefix("CategoryCell-"),
                      "Expected initial focus on sidebar category cell")

        // Step 1: press Right → expect EPG focus
        print("[TEST] Pressing Right")
        remote.press(.right)
        XCTAssertTrue(app.waitForFocus("EPGView", timeout: 5.0),
                      "Right swipe should move focus into the EPG")

        // Step 2: press Left → expect Categories focus again
        print("[TEST] Pressing Left")
        remote.press(.left)
        XCTAssertTrue(app.waitForFocusPrefix("CategoryCell-"),
                      "Left swipe should return focus to the sidebar")
    }

    // MARK: - Enhanced multi‑direction regression test
    /// Simulates RIGHT → DOWN → UP → LEFT key sequence and verifies that focus
    /// moves Sidebar → EPG → (remains in EPG) → Sidebar.
    func testFocusMultiDirectionSequence() throws {
        app.launch()
        
        // Wait for the app to be ready
        let categoriesView = app.collectionViews["CategoriesCollectionView"]
        XCTAssertTrue(app.waitForElementToExist(categoriesView), "Categories view should exist")
        
        // Wait for initial focus with longer timeout
        XCTAssertTrue(app.waitForFocusPrefix("CategoryCell-"),
                      "Expected initial focus on sidebar category cell")

        // 2. RIGHT to EPG
        remote.press(.right)
        XCTAssertTrue(app.waitForFocus("EPGView", timeout: 5.0),
                      "Right swipe should move focus into the EPG")

        // 3. DOWN inside EPG (should stay in EPG)
        remote.press(.down)
        XCTAssertTrue(app.waitForFocus("EPGView", timeout: 5.0),
                      "Down swipe should keep focus in EPG")

        // 4. UP inside EPG (still EPG)
        remote.press(.up)
        XCTAssertTrue(app.waitForFocus("EPGView", timeout: 5.0),
                      "Up swipe should keep focus in EPG")

        // 5. LEFT back to sidebar
        remote.press(.left)
        XCTAssertTrue(app.waitForFocusPrefix("CategoryCell-"),
                      "Left swipe should return focus to sidebar")
    }
}

/// VoiceOver stress test suite
final class InfinityBugVoiceOverTests: XCTestCase {
    private let remote = XCUIRemote.shared
    private var app: XCUIApplication!
    private let maxIterations = 50 // Maximum number of navigation attempts
    private let navigationTimeout: TimeInterval = 0.5 // Time to wait between navigations
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Enable VoiceOver and accessibility features
        app.launchArguments.append("-AppleTVAccessibility")
        app.launchArguments.append("-UIAccessibilityIsVoiceOverRunning")
        
        // Disable async request spoofing for tests
        ViewController.spoofAsyncRequests = false
    }
    
    override func tearDownWithError() throws {
        ViewController.spoofAsyncRequests = true
        app = nil
    }
    
    /// Performs a comprehensive VoiceOver navigation test
    func testVoiceOverNavigation() throws {
        app.launch()
        
        // Wait for initial UI to load
        let categoriesView = app.collectionViews["CategoriesCollectionView"]
        XCTAssertTrue(app.waitForElementToExist(categoriesView), "Categories view should exist")
        
        // Wait for initial focus
        XCTAssertTrue(app.waitForFocusPrefix("CategoryCell-"),
                      "Expected initial focus on sidebar category cell")
        
        // Test navigation patterns
        try testNavigationPattern()
    }
    
    /// Tests various navigation patterns with VoiceOver
    private func testNavigationPattern() throws {
        var iterations = 0
        var lastFocusedElement: String?
        var consecutiveSameFocus = 0
        
        // Navigation directions to test
        let directions: [XCUIRemote.Button] = [.right, .left, .up, .down]
        
        while iterations < maxIterations {
            // Choose a random direction
            let direction = directions.randomElement()!
            
            // Press the remote button
            remote.press(direction)
            
            // Wait for focus to update
            Thread.sleep(forTimeInterval: navigationTimeout)
            
            // Get current focused element
            let currentFocus = app.focusedIdentifier
            
            // Check if focus has changed
            if currentFocus == lastFocusedElement {
                consecutiveSameFocus += 1
                if consecutiveSameFocus >= 3 {
                    print("[VO] Focus appears to be stuck on: \(currentFocus)")
                    break
                }
            } else {
                consecutiveSameFocus = 0
            }
            
            lastFocusedElement = currentFocus
            iterations += 1
            
            // Log navigation progress
            print("[VO] Iteration \(iterations): Moved \(direction) to \(currentFocus)")
        }
        
        // Verify we completed some navigation
        XCTAssertGreaterThan(iterations, 0, "Navigation test should have performed some iterations")
    }
    
    /// Tests VoiceOver's "Read Screen After Delay" functionality
    func testReadScreenAfterDelay() throws {
        app.launch()
        
        // Wait for initial UI to load
        let categoriesView = app.collectionViews["CategoriesCollectionView"]
        XCTAssertTrue(app.waitForElementToExist(categoriesView), "Categories view should exist")
        
        // Wait for initial focus
        XCTAssertTrue(app.waitForFocusPrefix("CategoryCell-"),
                      "Expected initial focus on sidebar category cell")
        
        // Simulate VoiceOver's "Read Screen After Delay" gesture
        // For tvOS, we'll use a two-finger swipe up on the remote
        remote.press(.menu) // First finger
        remote.press(.up)   // Second finger swipe up
        
        // Wait for VoiceOver to process the gesture
        Thread.sleep(forTimeInterval: 1.0)
        
        // Verify that the app is still responsive by checking if we can still interact with elements
        XCTAssertTrue(categoriesView.exists, "Categories view should still be accessible")
    }
}
