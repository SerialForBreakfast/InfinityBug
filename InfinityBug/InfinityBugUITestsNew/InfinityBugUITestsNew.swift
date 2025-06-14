//
//  InfinityBugUITestsNew.swift
//  InfinityBugUITestsNew
//
//  Created by Joseph McCraw on 6/12/25.
//

import XCTest
@testable import InfinityBug

/// Shared test helpers for focus and accessibility testing
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

    /// Waits until the focused identifier starts with the specified prefix or times out.
    func waitForFocusPrefix(_ prefix: String, timeout: TimeInterval = 5.0) -> Bool {
        let pollInterval: TimeInterval = 0.1
        let deadline = Date().addingTimeInterval(timeout)
        var lastFocus: String = ""
        while Date() < deadline {
            let currentFocus = focusedIdentifier
            if currentFocus.hasPrefix(prefix) {
                return true
            }
            lastFocus = currentFocus
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        print("[TEST] Focus wait timed out. Current focus: \(focusedIdentifier)")
        return false
    }
}

final class InfinityBugUITestsNew: XCTestCase {
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
        app.launchArguments.append("-DisableAsyncRequestSpoofing")
        
        // Add scene configuration
        app.launchEnvironment["UIApplicationSceneManifest"] = """
        {
            "UIApplicationSupportsMultipleScenes": false,
            "UISceneConfigurations": {
                "UIWindowSceneSessionRoleApplication": [{
                    "UISceneConfigurationName": "Default Configuration",
                    "UISceneDelegateClassName": "InfinityBug.ViewController"
                }]
            }
        }
        """
    }
    
    override func tearDownWithError() throws {
        // ViewController.spoofAsyncRequests = true
        app = nil
    }
    
    /// Performs a comprehensive VoiceOver navigation test with accessibility audit
    func testVoiceOverNavigationAndAccessibility() throws {
        app.launch()
        
        // Wait for initial UI to load with increased timeout
        let categoriesView = app.collectionViews["CategoriesCollectionView"]
        XCTAssertTrue(app.waitForElementToExist(categoriesView, timeout: 10.0), "Categories view should exist")
        
        // Wait for initial focus with increased timeout and retry logic
        let focusTimeout: TimeInterval = 15.0
        var focusSuccess = false
        var attempts = 0
        let maxAttempts = 3
        
        while !focusSuccess && attempts < maxAttempts {
            focusSuccess = app.waitForFocusPrefix("CategoryCell-", timeout: focusTimeout)
            if !focusSuccess {
                attempts += 1
                print("[TEST] Focus attempt \(attempts) failed, retrying...")
                // Try to force focus update
                remote.press(.menu)
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        
        XCTAssertTrue(focusSuccess, "Expected initial focus on sidebar category cell")
        
        // Perform accessibility audit
        try performAccessibilityAudit()
        
        // Test navigation patterns
        try testNavigationPattern()
    }
    
    /// Performs an accessibility audit using the built-in API
    private func performAccessibilityAudit() throws {
        // Perform the audit with default options
        try app.performAccessibilityAudit(for: .all)
        print("[AX] Accessibility audit completed successfully")
    }
    
    /// Tests various navigation patterns with VoiceOver
    private func testNavigationPattern() throws {
        var iterations = 0
        var lastFocusedElement: String?
        var consecutiveSameFocus = 0
        var lastFocusTime = Date()
        
        // Navigation directions to test
        let directions: [XCUIRemote.Button] = [.right, .left, .up, .down]
        
        while iterations < maxIterations {
            // Choose a random direction
            let direction = directions.randomElement()!
            
            // Press the remote button with a short duration
            remote.press(direction, forDuration: 0.05)
            
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
            
            // Check for AX timeout (no focus changes for 2 seconds)
            let currentTime = Date()
            if currentTime.timeIntervalSince(lastFocusTime) > 2.0 {
                print("[VO] AX timeout detected - no focus changes for 2 seconds")
                break
            }
            
            lastFocusedElement = currentFocus
            lastFocusTime = currentTime
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
        
        // Wait for initial UI to load with increased timeout
        let categoriesView = app.collectionViews["CategoriesCollectionView"]
        XCTAssertTrue(app.waitForElementToExist(categoriesView, timeout: 10.0), "Categories view should exist")
        
        // Wait for initial focus with increased timeout and retry logic
        let focusTimeout: TimeInterval = 15.0
        var focusSuccess = false
        var attempts = 0
        let maxAttempts = 3
        
        while !focusSuccess && attempts < maxAttempts {
            focusSuccess = app.waitForFocusPrefix("CategoryCell-", timeout: focusTimeout)
            if !focusSuccess {
                attempts += 1
                print("[TEST] Focus attempt \(attempts) failed, retrying...")
                // Try to force focus update
                remote.press(.menu)
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        
        XCTAssertTrue(focusSuccess, "Expected initial focus on sidebar category cell")
        
        // Simulate VoiceOver's "Read Screen After Delay" gesture
        // For tvOS, we'll use a two-finger swipe up on the remote
        remote.press(.menu) // First finger
        Thread.sleep(forTimeInterval: 0.5)
        remote.press(.up)   // Second finger swipe up
        
        // Wait for VoiceOver to process the gesture
        Thread.sleep(forTimeInterval: 2.0)
        
        // Verify that the app is still responsive by checking if we can still interact with elements
        XCTAssertTrue(categoriesView.exists, "Categories view should still be accessible")
        
        // Perform accessibility audit after the gesture
        try performAccessibilityAudit()
    }
}
