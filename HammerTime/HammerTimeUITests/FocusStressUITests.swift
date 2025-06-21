//
//  FocusStressUITests.swift
//  HammerTimeUITests
//
//  Created by Joseph McCraw on 6/13/25.
//  UI Tests specifically for the FocusStressViewController DEBUG stress testing.
//  These tests validate InfinityBug detection under extreme focus stressor conditions.

import XCTest

/// Returns true when a focus ID refers to a real UI element (not empty/placeholder).
private func isValidFocus(_ id: String) -> Bool {
    return !id.isEmpty && id != "NONE" && id != "NO_FOCUS"
}

/// FocusStress-specific UI test suite for InfinityBug detection under stress.
/// Tests the FocusStressViewController with various stressor combinations.
final class FocusStressUITests: XCTestCase {
    
    var app: XCUIApplication!
    let remote = XCUIRemote.shared
    
    /// Scale factor for test intensity (default = 1, can be overridden via environment)
    private var stressFactor: Int {
        if let envValue = ProcessInfo.processInfo.environment["STRESS_FACTOR"],
           let factor = Int(envValue), factor > 0 {
            return factor
        }
        return 1
    }
    
    /// Number of alternating presses scaled by stress factor
    private var totalPresses: Int {
        return 200 * stressFactor
    }
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        
        // Launch with FocusStressMode heavy for comprehensive stress testing
        app.launchArguments += [
            "-FocusStressMode", "heavy",
            "-DebounceDisabled", "YES",
            "-FocusTestMode", "YES"
        ]
        
        app.launchEnvironment["DEBOUNCE_DISABLED"] = "1"
        app.launchEnvironment["FOCUS_TEST_MODE"] = "1"
        
        // Reset the bug detector before each run (via a placeholder since we can't call it directly)
        app.launchArguments += ["-ResetBugDetector"]
        
        // Set stress factor if specified
        if stressFactor != 1 {
            app.launchEnvironment["STRESS_FACTOR"] = "\(stressFactor)"
        }
        
        app.launch()
        
        // Wait for FocusStress harness to load
        sleep(3)
        
        // Verify we're in FocusStress mode
        let stressCollectionView = app.collectionViews["FocusStressCollectionView"]
        XCTAssertTrue(stressCollectionView.waitForExistence(timeout: 10),
                     "FocusStressCollectionView should exist - ensure app launched with -FocusStressMode heavy")
        
        NSLog("DIAGNOSTIC SETUP: FocusStress harness loaded with stress factor \(stressFactor) (total presses: \(totalPresses))")
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Helper Methods
    
    /// Sets up AXFocusDebugger logging to capture all debug output during test
    private func setupAXFocusDebuggerLogging() {
        // Listen for all AXFocusDebugger notifications and log them
        let notificationNames = [
            "UIAccessibilityElementFocusedNotification",
            "UIAccessibilityAnnouncementDidFinishNotification", 
            "UIAccessibilityVoiceOverStatusDidChangeNotification"
        ]
        
        for name in notificationNames {
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { notification in
                NSLog("AXDBG_TEST: Notification \(name) - \(notification.userInfo ?? [:])")
            }
        }
        
        // Force start AXFocusDebugger if not already started
        NSLog("AXDBG_TEST: Ensuring AXFocusDebugger is active")
    }
    
    /// Returns identifier of currently-focused element or "NONE"
    private var focusID: String {
        // Try the standard hasFocus predicate
        let focusedElements = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == true"))
        
        if focusedElements.count > 0 {
            let firstMatch = focusedElements.firstMatch
            if firstMatch.exists {
                let identifier = firstMatch.identifier
                if !identifier.isEmpty {
                    return identifier
                }
            }
        }
        
        // Try collection view specifically
        let stressCollectionView = app.collectionViews["FocusStressCollectionView"]
        if stressCollectionView.exists {
            let cells = stressCollectionView.cells
            for cellIndex in 0..<min(cells.count, 20) {
                let cell = cells.element(boundBy: cellIndex)
                if cell.exists && cell.hasFocus {
                    return cell.identifier
                }
            }
        }
        
        return "NONE"
    }
    
    /// Run test with specific stressor enabled
    private func runTestWithStressor(_ stressorNumber: Int, stressorName: String) throws {
        NSLog("DIAGNOSTIC STRESSOR: Testing individual stressor \(stressorNumber) (\(stressorName))")
        
        // Terminate current app and relaunch with specific stressor
        app.terminate()
        usleep(500_000) // 500ms pause
        
        // Launch with only specific stressor enabled
        app.launchArguments = [
            "-EnableStress\(stressorNumber)", "YES",
            "-DebounceDisabled", "YES",
            "-FocusTestMode", "YES"
        ]
        
        app.launch()
        sleep(2)
        
        // Verify collection view exists
        let stressCollectionView = app.collectionViews["FocusStressCollectionView"]
        XCTAssertTrue(stressCollectionView.waitForExistence(timeout: 10),
                     "FocusStressCollectionView should exist with stressor \(stressorNumber)")
        
        // Run reduced stress test (50 presses instead of 200)
        let reducedPresses = 50 * stressFactor
        var consecutiveStuck = 0
        var lastFocus = ""
        let maxStuckThreshold = 8
        
        NSLog("DIAGNOSTIC STRESSOR \(stressorNumber): Starting \(reducedPresses) alternating presses")
        
        for pressIndex in 0..<reducedPresses {
            let direction: XCUIRemote.Button = (pressIndex % 2 == 0) ? .right : .left
            let beforeFocus = focusID
            
            remote.press(direction, forDuration: 0.03)
            usleep(40_000) // 40ms between presses
            
            let afterFocus = focusID
            
            // Check for InfinityBug with valid focus only
            if beforeFocus == afterFocus && isValidFocus(afterFocus) {
                if lastFocus == afterFocus {
                    consecutiveStuck += 1
                    if consecutiveStuck > maxStuckThreshold {
                        NSLog("CRITICAL: INFINITY BUG DETECTED with stressor \(stressorNumber): Focus stuck on '\(afterFocus)' for \(consecutiveStuck) consecutive moves")
                        XCTFail("InfinityBug detected with stressor \(stressorNumber) (\(stressorName)): Focus stuck on \(afterFocus)")
                        return
                    }
                } else {
                    consecutiveStuck = 1
                    lastFocus = afterFocus
                }
            } else {
                consecutiveStuck = 0
                lastFocus = afterFocus
            }
            
            // Log progress every 10 presses
            if pressIndex % 10 == 0 {
                NSLog("STRESSOR \(stressorNumber)[\(pressIndex)]: \(direction) '\(beforeFocus)' → '\(afterFocus)' (stuck: \(consecutiveStuck))")
            }
        }
        
        NSLog("DIAGNOSTIC STRESSOR \(stressorNumber): Completed without InfinityBug (max stuck: \(consecutiveStuck))")
    }
    
    // MARK: - Main Tests
    
    /// Primary FocusStress test: Optimized for InfinityBug reproduction based on log analysis
    func testFocusStressInfinityBugDetection() throws {
        NSLog("DIAGNOSTIC: Starting optimized InfinityBug detection test with \(totalPresses) alternating presses")
        
        // Set up an expectation to wait for our high-confidence bug notification.
        // The test will FAIL if this notification is posted.
        let bugExpectation = XCTNSNotificationExpectation(name: Notification.Name("com.infinitybug.highConfidenceDetection"))
        bugExpectation.isInverted = true // Inverting means the test PASSES if the notification is NOT posted.
        
        let startTime = Date()
        var pressLog: [(press: Int, direction: String, beforeFocus: String, afterFocus: String)] = []
        
        // Phase 1: High-frequency cache seeding with repetitive directional bursts
        NSLog("DIAGNOSTIC: Phase 1 - High-frequency cache seeding with repetitive directional bursts")
        let seedBursts: [(direction: XCUIRemote.Button, count: Int)] = [
            (.right, 8), (.left, 6), (.up, 10), (.down, 7), (.right, 9), (.left, 5)
        ]
        for burst in seedBursts {
            for _ in 0..<burst.count {
                remote.press(burst.direction, forDuration: 0.008) // 8ms press
                usleep(8_000) // 8ms gap - high frequency input
            }
        }
        
        // Phase 2: Create layout stress while system is processing cached events
        NSLog("DIAGNOSTIC: Phase 2 - Layout stress during cache processing")
        for pressIndex in 0..<min(50, totalPresses) {
            let direction: XCUIRemote.Button = (pressIndex % 2 == 0) ? .right : .left
            let directionString = (direction == .right) ? "RIGHT" : "LEFT"
            
            let beforeFocus = focusID
            
            // Timing matched to log analysis: 25ms press, 30ms gap
            remote.press(direction, forDuration: 0.025)
            usleep(30_000)
            
            let afterFocus = focusID
            pressLog.append((press: pressIndex, direction: directionString, beforeFocus: beforeFocus, afterFocus: afterFocus))
        }
        
        // Phase 3: Rapid alternating to trigger stale cache replay
        NSLog("DIAGNOSTIC: Phase 3 - Rapid alternating to trigger phantom events")
        for pressIndex in 50..<totalPresses {
            let direction: XCUIRemote.Button = (pressIndex % 2 == 0) ? .right : .left
            let directionString = (direction == .right) ? "RIGHT" : "LEFT"
            
            let beforeFocus = focusID
            
            // Calibrated timing - fast enough to create stress, slow enough to allow processing
            remote.press(direction, forDuration: 0.025) // 25ms press duration
            usleep(40_000) // 40ms between presses - calibrated timing
            
            let afterFocus = focusID
            pressLog.append((press: pressIndex, direction: directionString, beforeFocus: beforeFocus, afterFocus: afterFocus))
            
            // Progress logging every 25 presses
            if pressIndex % 25 == 0 {
                let timeElapsed = Date().timeIntervalSince(startTime)
                NSLog("DIAGNOSTIC[\(pressIndex)/\(totalPresses)]: \(directionString) '\(beforeFocus)' → '\(afterFocus)' (time: \(String(format: "%.1f", timeElapsed))s)")
            }
        }
        
        // Wait for a short period to see if a notification is posted after the loop finishes.
        // If the bug was detected, the expectation will fail immediately.
        // If not, this will pass after the timeout.
        let result = XCTWaiter.wait(for: [bugExpectation], timeout: 2.0)
        
        if result == .completed {
            let totalTime = Date().timeIntervalSince(startTime)
            NSLog("DIAGNOSTIC SUCCESS: Completed \(totalPresses) presses in \(String(format: "%.1f", totalTime))s without high-confidence InfinityBug detection.")
            // Analyze unique focus states
            let uniqueFocuses = Set(pressLog.map { $0.afterFocus }.filter { isValidFocus($0) })
            NSLog("DIAGNOSTIC ANALYSIS: Encountered \(uniqueFocuses.count) unique valid focus states")
            XCTAssertGreaterThan(uniqueFocuses.count, 3, "Should encounter multiple different focus states during stress test")
        } else {
            XCTFail("High-confidence InfinityBug was detected by the InfinityBugDetector. See logs for diagnostics.")
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        // Verify test completed within time limit (90s * stress factor)
        let timeLimit = 90.0 * Double(stressFactor)
        XCTAssertLessThan(totalTime, timeLimit, "Test should complete within \(timeLimit)s (actual: \(String(format: "%.1f", totalTime))s)")
    }
    
    /// Test each individual stressor to isolate InfinityBug causes
    func testIndividualStressors() throws {
        let stressors: [(number: Int, name: String)] = [
            (1, "Nested Layout"),
            (2, "Hidden Focusable Traps"),
            (3, "Jiggle Timer"),
            (4, "Circular Focus Guides"),
            (5, "Duplicate Identifiers")
        ]
        
        for stressor in stressors {
            try runTestWithStressor(stressor.number, stressorName: stressor.name)
        }
    }
    
    /// Test FocusStress collection view accessibility
    func testFocusStressAccessibilitySetup() throws {
        NSLog("DIAGNOSTIC: Testing FocusStress accessibility setup")
        
        let stressCollectionView = app.collectionViews["FocusStressCollectionView"]
        XCTAssertTrue(stressCollectionView.exists, "FocusStressCollectionView should exist")
        XCTAssertTrue(stressCollectionView.isHittable, "FocusStressCollectionView should be hittable")
        
        // Verify some cells exist and have proper accessibility setup
        var cellsFound = 0
        var cellsWithDuplicateIDs = 0
        
        // Check first 20 cells (avoid timeout issues)
        for section in 0..<3 {
            for item in 0..<10 {
                let cellID = "cell-\(section)-\(item)"
                let duplicateID = "dupCell"
                
                let cell = app.cells[cellID]
                let duplicateCell = app.cells[duplicateID]
                
                if cell.exists {
                    cellsFound += 1
                    NSLog("DIAGNOSTIC CELL: Found cell with ID '\(cellID)'")
                }
                
                if duplicateCell.exists {
                    cellsWithDuplicateIDs += 1
                    NSLog("DIAGNOSTIC DUPLICATE: Found cell with duplicate ID '\(duplicateID)'")
                }
            }
        }
        
        NSLog("DIAGNOSTIC ACCESSIBILITY: Found \(cellsFound) unique cells, \(cellsWithDuplicateIDs) duplicate ID cells")
        XCTAssertGreaterThan(cellsFound, 5, "Should find multiple cells with proper identifiers")
        
        // If duplicate IDs are enabled, we should find some
        if cellsWithDuplicateIDs > 0 {
            NSLog("DIAGNOSTIC DUPLICATE: Duplicate identifier stress is active")
        }
    }
    
    /// Test designed to trigger phantom event cache corruption through repetitive directional input with heavy right exploration
    func testPhantomEventCacheBugReproduction() throws {
        NSLog("DIAGNOSTIC: Testing phantom event cache corruption through repetitive directional input with AXFocusDebugger integration")
        
        // Enable detailed AXFocusDebugger logging during test
        self.setupAXFocusDebuggerLogging()
        
        // Set up expectation for InfinityBug detection
        let bugExpectation = XCTNSNotificationExpectation(name: Notification.Name("com.infinitybug.highConfidenceDetection"))
        bugExpectation.isInverted = true
        
        let startTime = Date()
        
                 // Phase 1: Cache flooding with multi-directional input to create event backlog
        NSLog("DIAGNOSTIC PHANTOM: Phase 1 - Cache flooding with multi-directional input")
        let floodDirections: [XCUIRemote.Button] = [.up, .right, .down, .left, .up, .right, .down, .left]
        for direction in floodDirections {
            for _ in 0..<3 {
                remote.press(direction, forDuration: 0.025) // 25ms press
                usleep(40_000) // 40ms gap - timing based on successful manual reproduction
            }
        }
        
        // Phase 2: Repetitive directional bursts matching successful manual reproduction pattern with increased right exploration
        NSLog("DIAGNOSTIC PHANTOM: Phase 2 - Repetitive directional bursts with heavy right exploration")
        
        let burstPatterns: [(direction: XCUIRemote.Button, count: Int)] = [
            (.right, 20),   // Start with heavy right exploration
            (.down, 12),    // Down 12x (like your manual)
            (.right, 18),   // More right exploration  
            (.left, 8),     // Left 8x
            (.right, 22),   // Even more right
            (.up, 15),      // Up 15x  
            (.right, 16),   // Keep exploring right
            (.down, 10),    // Down 10x
            (.right, 14),   // Right again
            (.left, 9),     // Left 9x
            (.right, 25),   // Extended right exploration
            (.up, 18),      // Up 18x
            (.right, 19),   // More right
            (.down, 8),     // Down 8x
            (.right, 17),   // Right again
            (.left, 12),    // Left 12x
            (.right, 21),   // Final heavy right burst
            (.up, 13)       // Up 13x
        ]
        
        for (burstIndex, burst) in burstPatterns.enumerated() {
            NSLog("DIAGNOSTIC PHANTOM: Burst \(burstIndex): \(burst.direction) x\(burst.count)")
            
                         for pressIndex in 0..<burst.count {
                let beforeFocus = focusID
                
                // Timing calibrated to match successful manual reproduction pattern
                remote.press(burst.direction, forDuration: 0.025) // 25ms press
                usleep(50_000) // 50ms gap - allows focus processing between inputs
                
                let afterFocus = focusID
                
                // Log first and last few of each burst with detailed focus info
                if pressIndex < 3 || pressIndex >= (burst.count - 3) {
                    NSLog("DIAGNOSTIC PHANTOM[B\(burstIndex)P\(pressIndex)]: \(burst.direction) '\(beforeFocus)' → '\(afterFocus)'")
                    
                    // Additional detailed focus state logging
                    if beforeFocus != afterFocus {
                        NSLog("AXDBG_TEST: FOCUS CHANGE DETECTED - Burst \(burstIndex) Press \(pressIndex)")
                    }
                }
            }
            
            // Brief pause between bursts to let system process
            usleep(100_000) // 100ms pause between bursts
        }
        
        // Phase 3A: Extended right directional exploration to replicate manual testing behavior
        NSLog("DIAGNOSTIC PHANTOM: Phase 3A - Extended right directional exploration")
        for rightIndex in 0..<35 {
            let beforeFocus = focusID
            
            remote.press(.right, forDuration: 0.025)
            usleep(45_000) // 45ms gap for focus processing
            
            let afterFocus = focusID
            
            if rightIndex % 5 == 0 {
                NSLog("DIAGNOSTIC PHANTOM[ExtendedRight\(rightIndex)]: RIGHT '\(beforeFocus)' → '\(afterFocus)'")
                if beforeFocus != afterFocus {
                    NSLog("AXDBG_TEST: RIGHT EXPLORATION CAUSING FOCUS CHANGES - Index \(rightIndex)")
                }
            }
        }
        
        // Phase 3B: Randomized directional input with right-weighted distribution
        NSLog("DIAGNOSTIC PHANTOM: Phase 3B - Randomized input with right-weighted distribution")
        let chaosDirections: [XCUIRemote.Button] = [.right, .right, .right, .up, .down, .left, .right] // Right-weighted distribution
        
        for chaosIndex in 0..<80 {
            let direction = chaosDirections.randomElement()!
            let beforeFocus = focusID
            
            // Randomized timing - fast enough to create stress, slow enough to allow processing
            remote.press(direction, forDuration: 0.020) // 20ms press
            usleep(30_000) // 30ms gap - controlled timing for system processing
            
            let afterFocus = focusID
            
            if chaosIndex % 15 == 0 {
                NSLog("DIAGNOSTIC PHANTOM[Chaos\(chaosIndex)]: \(direction) '\(beforeFocus)' → '\(afterFocus)'")
                if direction == .right {
                    NSLog("AXDBG_TEST: RIGHT CHAOS PRESS - Index \(chaosIndex)")
                }
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        NSLog("DIAGNOSTIC PHANTOM: Phantom event cache reproduction test completed in \(String(format: "%.1f", totalTime))s")
        
        // Wait for potential bug detection with extended timeout for randomized input processing
        let result = XCTWaiter.wait(for: [bugExpectation], timeout: 3.0)
        
        if result == .completed {
            NSLog("DIAGNOSTIC PHANTOM: No high-confidence InfinityBug detected after phantom event cache reproduction test")
        } else {
            XCTFail("Phantom event cache reproduction test triggered InfinityBug detection - SUCCESS!")
        }
    }

    /// Test FocusStress performance under stress
    func testFocusStressPerformanceStress() throws {
        NSLog("DIAGNOSTIC: Testing performance under stress conditions")
        
        let startTime = Date()
        var responsivePresses = 0
        let testPresses = 50 * stressFactor
        
        for pressIndex in 0..<testPresses {
            let direction: XCUIRemote.Button = [.right, .left, .up, .down].randomElement()!
            let beforeFocus = focusID
            
            let pressStartTime = Date()
            remote.press(direction, forDuration: 0.02)
            usleep(25_000) // 25ms between presses
            
            let afterFocus = focusID
            let pressTime = Date().timeIntervalSince(pressStartTime)
            
            // Consider press "responsive" if focus changed or if it was already at a valid element
            if beforeFocus != afterFocus || isValidFocus(afterFocus) {
                responsivePresses += 1
            }
            
            // Log slow presses
            if pressTime > 0.1 {
                NSLog("DIAGNOSTIC SLOW: Press \(pressIndex) took \(String(format: "%.3f", pressTime))s")
            }
            
            if pressIndex % 10 == 0 {
                NSLog("DIAGNOSTIC PERF[\(pressIndex)]: \(direction) responsive: \(responsivePresses)/\(pressIndex + 1)")
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let responsivePercentage = Double(responsivePresses) / Double(testPresses) * 100.0
        
        NSLog("DIAGNOSTIC PERFORMANCE: \(responsivePresses)/\(testPresses) presses responsive (\(String(format: "%.1f", responsivePercentage))%) in \(String(format: "%.1f", totalTime))s")
        
        // Performance assertions
        XCTAssertGreaterThan(responsivePercentage, 60.0, "At least 60% of presses should be responsive under stress")
        XCTAssertLessThan(totalTime, 30.0 * Double(stressFactor), "Performance test should complete within reasonable time")
    }
} 