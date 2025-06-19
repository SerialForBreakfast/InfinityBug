//
//  TortureRackUITests.swift
//  HammerTimeUITests
//
//  Created by Joseph McCraw on 6/13/25.
//  UI Tests specifically for the TortureRackViewController DEBUG stress testing.
//  These tests validate InfinityBug detection under extreme focus stressor conditions.

import XCTest

/// Returns true when a focus ID refers to a real UI element (not empty/placeholder).
private func isValidFocus(_ id: String) -> Bool {
    return !id.isEmpty && id != "NONE" && id != "NO_FOCUS"
}

/// TortureRack-specific UI test suite for InfinityBug detection under stress.
/// Tests the TortureRackViewController with various stressor combinations.
final class TortureRackUITests: XCTestCase {
    
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
        
        // Launch with TortureMode heavy for maximum stress
        app.launchArguments += [
            "-TortureMode", "heavy",
            "-DebounceDisabled", "YES",
            "-FocusTestMode", "YES"
        ]
        
        app.launchEnvironment["DEBOUNCE_DISABLED"] = "1"
        app.launchEnvironment["FOCUS_TEST_MODE"] = "1"
        
        // Set stress factor if specified
        if stressFactor != 1 {
            app.launchEnvironment["STRESS_FACTOR"] = "\(stressFactor)"
        }
        
        app.launch()
        
        // Wait for TortureRack to load
        sleep(3)
        
        // Verify we're in TortureRack mode
        let tortureCollectionView = app.collectionViews["TortureRackOuterCV"]
        XCTAssertTrue(tortureCollectionView.waitForExistence(timeout: 10), 
                     "TortureRackOuterCV should exist - ensure app launched with -TortureMode heavy")
        
        NSLog("TORTURE SETUP: TortureRack loaded with stress factor \(stressFactor) (total presses: \(totalPresses))")
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Helper Methods
    
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
        let tortureCollectionView = app.collectionViews["TortureRackOuterCV"]
        if tortureCollectionView.exists {
            let cells = tortureCollectionView.cells
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
        NSLog("TORTURE STRESSOR: Testing individual stressor \(stressorNumber) (\(stressorName))")
        
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
        let tortureCollectionView = app.collectionViews["TortureRackOuterCV"]
        XCTAssertTrue(tortureCollectionView.waitForExistence(timeout: 10), 
                     "TortureRackOuterCV should exist with stressor \(stressorNumber)")
        
        // Run reduced stress test (50 presses instead of 200)
        let reducedPresses = 50 * stressFactor
        var consecutiveStuck = 0
        var lastFocus = ""
        let maxStuckThreshold = 8
        
        NSLog("TORTURE STRESSOR \(stressorNumber): Starting \(reducedPresses) alternating presses")
        
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
        
        NSLog("TORTURE STRESSOR \(stressorNumber): Completed without InfinityBug (max stuck: \(consecutiveStuck))")
    }
    
    // MARK: - Main Tests
    
    /// Primary TortureRack test: 200 alternating left/right presses with InfinityBug detection
    func testTortureRackInfinityBugDetection() throws {
        NSLog("TORTURE: Starting main InfinityBug detection test with \(totalPresses) alternating presses")
        
        let startTime = Date()
        var consecutiveStuck = 0
        var lastFocus = ""
        let maxStuckThreshold = 8
        var pressLog: [(press: Int, direction: String, beforeFocus: String, afterFocus: String)] = []
        
        for pressIndex in 0..<totalPresses {
            let direction: XCUIRemote.Button = (pressIndex % 2 == 0) ? .right : .left
            let directionString = (direction == .right) ? "RIGHT" : "LEFT"
            
            let beforeFocus = focusID
            
            // Fast alternating presses to stress the focus system
            remote.press(direction, forDuration: 0.025) // 25ms press duration
            usleep(30_000) // 30ms between presses
            
            let afterFocus = focusID
            pressLog.append((press: pressIndex, direction: directionString, beforeFocus: beforeFocus, afterFocus: afterFocus))
            
            // InfinityBug detection: check for stuck focus on valid elements only
            if beforeFocus == afterFocus && isValidFocus(afterFocus) {
                if lastFocus == afterFocus {
                    consecutiveStuck += 1
                    NSLog("TORTURE STUCK[\(pressIndex)]: Focus stuck on '\(afterFocus)' for \(consecutiveStuck) consecutive moves")
                    
                    if consecutiveStuck > maxStuckThreshold {
                        let timeElapsed = Date().timeIntervalSince(startTime)
                        NSLog("CRITICAL: INFINITY BUG DETECTED at press \(pressIndex) after \(String(format: "%.1f", timeElapsed))s")
                        NSLog("STUCK PATTERN: Focus infinitely stuck on '\(afterFocus)' for \(consecutiveStuck) consecutive moves")
                        
                        // Log recent press history for debugging
                        let recentHistory = pressLog.suffix(10)
                        NSLog("RECENT HISTORY:")
                        for entry in recentHistory {
                            NSLog("  [\(entry.press)] \(entry.direction): '\(entry.beforeFocus)' → '\(entry.afterFocus)'")
                        }
                        
                        XCTFail("INFINITY BUG DETECTED: Focus stuck on '\(afterFocus)' for \(consecutiveStuck) consecutive moves after \(pressIndex) presses")
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
            
            // Progress logging every 25 presses
            if pressIndex % 25 == 0 {
                let timeElapsed = Date().timeIntervalSince(startTime)
                NSLog("TORTURE[\(pressIndex)/\(totalPresses)]: \(directionString) '\(beforeFocus)' → '\(afterFocus)' (stuck: \(consecutiveStuck), time: \(String(format: "%.1f", timeElapsed))s)")
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        NSLog("TORTURE SUCCESS: Completed \(totalPresses) presses in \(String(format: "%.1f", totalTime))s without InfinityBug")
        NSLog("TORTURE STATS: Max consecutive stuck count: \(consecutiveStuck)")
        
        // Verify test completed within time limit (90s * stress factor)
        let timeLimit = 90.0 * Double(stressFactor)
        XCTAssertLessThan(totalTime, timeLimit, "Test should complete within \(timeLimit)s (actual: \(String(format: "%.1f", totalTime))s)")
        
        // Verify we didn't hit InfinityBug
        XCTAssertLessThanOrEqual(consecutiveStuck, maxStuckThreshold, "Focus should not be stuck for more than \(maxStuckThreshold) consecutive moves")
        
        // Analyze unique focus states
        let uniqueFocuses = Set(pressLog.map { $0.afterFocus }.filter { isValidFocus($0) })
        NSLog("TORTURE ANALYSIS: Encountered \(uniqueFocuses.count) unique valid focus states")
        XCTAssertGreaterThan(uniqueFocuses.count, 3, "Should encounter multiple different focus states during stress test")
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
    
    /// Test TortureRack collection view accessibility
    func testTortureRackAccessibilitySetup() throws {
        NSLog("TORTURE: Testing TortureRack accessibility setup")
        
        let tortureCollectionView = app.collectionViews["TortureRackOuterCV"]
        XCTAssertTrue(tortureCollectionView.exists, "TortureRackOuterCV should exist")
        XCTAssertTrue(tortureCollectionView.isHittable, "TortureRackOuterCV should be hittable")
        
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
                    NSLog("TORTURE CELL: Found cell with ID '\(cellID)'")
                }
                
                if duplicateCell.exists {
                    cellsWithDuplicateIDs += 1
                    NSLog("TORTURE DUPLICATE: Found cell with duplicate ID '\(duplicateID)'")
                }
            }
        }
        
        NSLog("TORTURE ACCESSIBILITY: Found \(cellsFound) unique cells, \(cellsWithDuplicateIDs) duplicate ID cells")
        XCTAssertGreaterThan(cellsFound, 5, "Should find multiple cells with proper identifiers")
        
        // If duplicate IDs are enabled, we should find some
        if cellsWithDuplicateIDs > 0 {
            NSLog("TORTURE DUPLICATE: Duplicate identifier stress is active")
        }
    }
    
    /// Test TortureRack performance under stress
    func testTortureRackPerformanceStress() throws {
        NSLog("TORTURE: Testing performance under stress conditions")
        
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
                NSLog("TORTURE SLOW: Press \(pressIndex) took \(String(format: "%.3f", pressTime))s")
            }
            
            if pressIndex % 10 == 0 {
                NSLog("TORTURE PERF[\(pressIndex)]: \(direction) responsive: \(responsivePresses)/\(pressIndex + 1)")
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let responsivePercentage = Double(responsivePresses) / Double(testPresses) * 100.0
        
        NSLog("TORTURE PERFORMANCE: \(responsivePresses)/\(testPresses) presses responsive (\(String(format: "%.1f", responsivePercentage))%) in \(String(format: "%.1f", totalTime))s")
        
        // Performance assertions
        XCTAssertGreaterThan(responsivePercentage, 60.0, "At least 60% of presses should be responsive under stress")
        XCTAssertLessThan(totalTime, 30.0 * Double(stressFactor), "Performance test should complete within reasonable time")
    }
} 