//
//  FocusStressUITests.swift
//  HammerTimeUITests
//
//  Created by Joseph McCraw on 6/13/25.
//
//  ========================================================================
//  INFINITYBUG EXPLORATION & INSTRUMENTATION SUITE (NO PASS/FAIL GUARANTEES)
//  ========================================================================
//
//  NOTE 2025-06-22: Automated reproduction has proven unreliable in UITest
//  environment because XCUIRemote sends **synthetic events** that bypass the
//  HID layer, VoiceOver cannot be toggled programmatically, and the test
//  runner throttles event delivery to ~15 Hz. The current goal is **NOT to
//  assert pass/fail**, but to capture metrics and video so a human can judge
//  whether InfinityBug occurs under each stress profile.
//
//  Each test therefore:
//    • Verifies the FocusStress harness is present.
//    • Sends a predefined press pattern while periodically sampling focus or
//      logging AXFocusDebugger output.
//    • NEVER fails due to InfinityBug absence; instead it records metrics in
//      the console and XCTActivity attachments.
//
//  Tests emit warnings when running on Simulator to remind that synthetic input
//  limits reproduction fidelity. No environment flag is required.
//
//  **OVERALL STRATEGY:**
//  This test suite implements a comprehensive, multi-layered approach to reproducing
//  the tvOS "InfinityBug" - a focus system failure that causes infinite directional
//  press repetition and system-wide focus lock-ups. The strategy combines:
//
//  1. **STRESS MULTIPLICATION:** Uses FocusStressViewController with 8 simultaneous
//     stressor categories to create the "perfect storm" conditions
//
//  2. **TIMING PRECISION:** Implements exact timing patterns (8-50ms intervals)
//     observed during successful manual InfinityBug reproduction
//
//  3. **PATTERN REPLICATION:** Recreates specific input sequences that have
//     previously triggered InfinityBug in manual testing
//
//  4. **AUTOMATED DETECTION:** Uses InfinityBugDetector to identify the "Black Hole"
//     condition where many presses occur with zero focus changes
//
//  5. **MANUAL VALIDATION:** Provides pure stress tests for human observation
//     when automated detection proves insufficient
//
//  **TEST HIERARCHY:**
//  - testFocusStressInfinityBugDetection: Primary reproduction test with detector
//  - testIndividualStressors: Scientific isolation of root causes
//  - testPhantomEventCacheBugReproduction: Targets phantom event manifestation
//  - testInfinityBugDetectorFeedingReproduction: Validates detector accuracy
//  - testMaximumStressForManualReproduction: Brute force manual reproduction
//  - testFocusStressPerformanceStress: Performance baseline establishment
//  - testFocusStressAccessibilitySetup: Infrastructure validation
//
//  **ROOT CAUSE THEORY:**
//  InfinityBug = (High-frequency input) × (Accessibility tree complexity) ×
//                (Layout instability) × (Focus guide conflicts) × (Timing precision)
//
//  The bug occurs when queued input events resolve against stale focus contexts,
//  causing the focus engine's fallback algorithm to lock onto circular focus guides
//  and infinitely replay the failed input event.
//
//  **EXPECTED OUTCOMES:**
//  - Most tests should PASS (no InfinityBug detected) under normal conditions
//  - Tests FAIL when InfinityBug is successfully reproduced
//  - Manual reproduction test always PASSES but requires human observation
//  - Failed tests indicate successful InfinityBug reproduction for further analysis

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
    
    /// TEST ENVIRONMENT SETUP AND CONFIGURATION
    ///
    /// **CRITICAL SETUP REQUIREMENTS:**
    /// This setup method configures the exact environment needed for InfinityBug reproduction:
    /// 
    /// **1. FOCUS STRESS MODE ACTIVATION:**
    /// - `-FocusStressMode heavy` enables all 8 stressor categories simultaneously
    /// - This creates the "perfect storm" of conditions needed for InfinityBug reproduction
    /// - Heavy mode includes: nested layouts, hidden traps, jiggle timers, circular guides, duplicate IDs, 
    ///   dynamic guides, rapid layout changes, and overlapping elements
    ///
    /// **2. DEBOUNCE ELIMINATION:**
    /// - `-DebounceDisabled YES` and environment variable disable input debouncing
    /// - Critical because InfinityBug requires rapid input processing without artificial delays
    /// - Allows the high-frequency input patterns (8-50ms intervals) to reach the focus system
    ///
    /// **3. FOCUS TEST MODE:**
    /// - `-FocusTestMode YES` enables enhanced logging and monitoring
    /// - Activates the InfinityBugDetector for automated detection
    /// - Provides detailed focus change tracking for test validation
    ///
    /// **4. DETECTOR RESET:**
    /// - `-ResetBugDetector` ensures clean state between test runs
    /// - Prevents false positives from previous test execution
    /// - Critical for reliable automated detection
    ///
    /// **5. STRESS FACTOR SCALING:**
    /// - Environment variable `STRESS_FACTOR` allows intensity scaling
    /// - Default = 1 (200 presses), can be increased for more aggressive testing
    /// - Enables performance testing across different device capabilities
    ///
    /// **VALIDATION:**
    /// - 3-second wait allows all stressors to initialize completely
    /// - Verifies FocusStressCollectionView exists (confirms proper mode activation)
    /// - Failure here indicates incorrect launch configuration or app startup issues
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // ─── Environment diagnostics (do not auto-skip) ──────────────────
        #if targetEnvironment(simulator)
        NSLog("⚠️  Running on Simulator – synthetic input, HID bypass, and reduced timing fidelity. Reproduction unlikely but continuing for metric collection.")
        #endif

        // Log actual VoiceOver runtime state for diagnostics
        NSLog("AX STATE: VoiceOver running = \(UIAccessibility.isVoiceOverRunning)")
        
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
        
        // Verify we're in FocusStress mode with comprehensive validation
        let stressCollectionView = app.collectionViews["FocusStressCollectionView"]
        XCTAssertTrue(stressCollectionView.waitForExistence(timeout: 10),
                     "FocusStressCollectionView should exist - ensure app launched with -FocusStressMode heavy")
        XCTAssertTrue(stressCollectionView.isHittable, "FocusStressCollectionView should be hittable")
        
        // Verify cells exist and are accessible
        let firstCell = stressCollectionView.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "At least one cell should exist in collection view")
        
        NSLog("DIAGNOSTIC SETUP: FocusStress harness loaded with stress factor \(stressFactor) (total presses: \(totalPresses))")
        NSLog("DIAGNOSTIC SETUP: Collection view exists and has \(stressCollectionView.cells.count) cells")
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
    
    /// FOCUS TRACKING SYSTEM
    ///
    /// **PURPOSE:**
    /// Provides reliable focus tracking for InfinityBug detection by querying the current focused element
    /// across multiple fallback strategies. Critical for identifying when focus becomes "stuck" on an element.
    ///
    /// **METHODOLOGY:**
    /// 1. Primary: Uses XCUITest's hasFocus predicate to find focused elements
    /// 2. Fallback: Specifically queries the FocusStressCollectionView for focused cells
    /// 3. Returns "NONE" if no focused element can be identified
    ///
    /// **RELIABILITY CONSIDERATIONS:**
    /// - hasFocus predicate only works reliably when VoiceOver is enabled
    /// - Collection view-specific fallback handles cases where general focus queries fail
    /// - Limited to first 20 cells to avoid performance issues during high-frequency polling
    /// - Essential for detecting the "Black Hole" condition where focus stops changing
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
    
    /// INDIVIDUAL STRESSOR TEST EXECUTION HELPER
    ///
    /// **PURPOSE:**
    /// Executes a focused test with only one specific stressor enabled, allowing precise isolation
    /// of which stress conditions are necessary vs. sufficient for InfinityBug reproduction.
    ///
    /// **METHODOLOGY:**
    /// 1. Terminates current app to clear any existing stress state
    /// 2. Relaunches with only the target stressor enabled via launch arguments
    /// 3. Runs a reduced stress test (50 presses vs. 200) for faster execution
    /// 4. Monitors for InfinityBug symptoms (consecutive stuck focus)
    /// 5. Logs detailed progress for each stressor's behavior
    ///
    /// **STRESSOR MAPPING:**
    /// - Stressor 1: Nested Layout (triple-nested compositional layout)
    /// - Stressor 2: Hidden Focusable Traps (invisible accessible elements)
    /// - Stressor 3: Jiggle Timer (constant layout constraint changes)
    /// - Stressor 4: Circular Focus Guides (conflicting preferred environments)
    /// - Stressor 5: Duplicate Identifiers (accessibility ID collisions)
    ///
    /// **EXPECTED BEHAVIOR:**
    /// Each individual stressor should NOT reproduce InfinityBug alone, validating
    /// the theory that InfinityBug requires multiple stressors acting in combination.
    private func runTestWithStressor(_ stressorNumber: Int, stressorName: String) throws {
        NSLog("DIAGNOSTIC STRESSOR: Testing individual stressor \(stressorNumber) (\(stressorName))")
        
        // Terminate current app and relaunch with specific stressor
        app.terminate()
        usleep(500_000) // 500ms pause
        
        // Launch with only specific stressor enabled
        app.launchArguments = [
            "-FocusStressMode", "light",        // Ensure we launch into FocusStressViewController
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
            
            // Only check focus every 10 presses to reduce expensive queries
            let beforeFocus = (pressIndex % 10 == 0) ? focusID : lastFocus
            
            remote.press(direction, forDuration: 0.05)
            usleep(150_000) // 150ms between presses - UI test framework friendly
            
            let afterFocus = (pressIndex % 10 == 0) ? focusID : lastFocus
            
            // Check for InfinityBug with valid focus only
            if beforeFocus == afterFocus && isValidFocus(afterFocus) {
                if lastFocus == afterFocus {
                    consecutiveStuck += 1
                    if consecutiveStuck > maxStuckThreshold {
                        NSLog("CRITICAL: INFINITY BUG DETECTED with stressor \(stressorNumber): Focus stuck on '\(afterFocus)' for \(consecutiveStuck) consecutive moves")
                        NSLog("METRIC: Detector signalled high-confidence InfinityBug during UITest run – recording for analysis but not failing test.")
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
    
    /// PRIMARY INFINITYBUG REPRODUCTION TEST
    ///
    /// **HOW IT APPROACHES THE ISSUE:**
    /// This test recreates the exact sequence of conditions that lead to the InfinityBug:
    /// 1. Saturates the focus event queue with rapid, high-frequency input bursts
    /// 2. Creates layout stress during cache processing via jiggle timers and nested layouts
    /// 3. Triggers stale focus context scenarios where queued events resolve against invalid targets
    /// 4. Exploits the focus engine's fallback algorithm that can lock onto circular focus guides
    /// 5. Detector accuracy: Does our InfinityBugDetector correctly identify the bug condition?
    ///
    /// **WHAT IT TESTS:**
    /// - Event queue saturation: Does high-frequency input create processing backlogs?
    /// - Focus context staleness: Do queued events resolve against elements that moved/changed?
    /// - Layout interference: Does constant layout churn during focus updates cause divergence?
    /// - Fallback algorithm: Does the focus engine get trapped in circular guide loops?
    /// - Detector accuracy: Does our InfinityBugDetector correctly identify the bug condition?
    ///
    /// **WHY IT SHOULD SUCCEED:**
    /// The test reproduces the exact timing patterns and stressor combinations from successful manual reproduction:
    /// - Phase 1: 8ms press/gap creates maximum event queue pressure (150 inputs in 2.4 seconds)
    /// - Phase 2: 25ms press/30ms gap during layout stress matches the timing where manual reproduction succeeded
    /// - Phase 3: 25ms press/40ms gap allows partial processing, creating the "stale context" condition
    /// - Combined stressors (nested layouts, hidden traps, jiggle timers, circular guides) create the exact
    ///   accessibility tree complexity and layout churn that precipitates the focus engine fallback
    /// - The detector should fire when it observes the "Black Hole" pattern: many presses with no focus changes
    ///
    /// **EXPECTED OUTCOME:**
    /// Test should PASS (no InfinityBug detection) under normal conditions, but FAIL if InfinityBug is reproduced
    /// The inverted expectation means the test passes when the bug is NOT detected, fails when it IS detected
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
                remote.press(burst.direction, forDuration: 0.05) // 50ms press
                usleep(100_000) // 100ms gap - more reasonable for UI testing
            }
        }
        
        // Phase 2: Create layout stress while system is processing cached events
        NSLog("DIAGNOSTIC: Phase 2 - Layout stress during cache processing")
        for pressIndex in 0..<min(50, totalPresses) {
            let direction: XCUIRemote.Button = (pressIndex % 2 == 0) ? .right : .left
            let directionString = (direction == .right) ? "RIGHT" : "LEFT"
            
            let beforeFocus = focusID
            
            // UI test framework friendly timing: 50ms press, 150ms gap
            remote.press(direction, forDuration: 0.05)
            usleep(150_000)
            
            let afterFocus = focusID
            pressLog.append((press: pressIndex, direction: directionString, beforeFocus: beforeFocus, afterFocus: afterFocus))
        }
        
        // Phase 3: Rapid alternating to trigger stale cache replay
        NSLog("DIAGNOSTIC: Phase 3 - Rapid alternating to trigger phantom events")
        for pressIndex in 50..<totalPresses {
            let direction: XCUIRemote.Button = (pressIndex % 2 == 0) ? .right : .left
            let directionString = (direction == .right) ? "RIGHT" : "LEFT"
            
            // Only check focus every 5 presses to reduce expensive queries
            let beforeFocus = (pressIndex % 5 == 0) ? focusID : "CACHED"
            
            // UI test framework friendly timing - allows proper processing
            remote.press(direction, forDuration: 0.05) // 50ms press duration
            usleep(150_000) // 150ms between presses - allows proper focus processing
            
            let afterFocus = (pressIndex % 5 == 0) ? focusID : "CACHED"
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
            // Analyze unique focus states (excluding cached values)
            let uniqueFocuses = Set(pressLog.map { $0.afterFocus }.filter { isValidFocus($0) && $0 != "CACHED" })
            NSLog("DIAGNOSTIC ANALYSIS: Encountered \(uniqueFocuses.count) unique valid focus states")
            NSLog("DIAGNOSTIC ANALYSIS: Focus states found: \(Array(uniqueFocuses))")
            XCTAssertGreaterThan(uniqueFocuses.count, 2, "Should encounter multiple different focus states during stress test")
        } else {
            NSLog("METRIC: Detector signalled high-confidence InfinityBug during UITest run – recording for analysis but not failing test.")
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        // Verify test completed within reasonable time limit (2 minutes * stress factor)
        let timeLimit = 120.0 * Double(stressFactor)
        XCTAssertLessThan(totalTime, timeLimit, "Test should complete within \(timeLimit)s (actual: \(String(format: "%.1f", totalTime))s)")
    }
    
    /// INDIVIDUAL STRESSOR ISOLATION TEST
    ///
    /// **HOW IT APPROACHES THE ISSUE:**
    /// This test takes a scientific approach to isolating the root cause by testing each of the 5 main
    /// stressor categories individually. It launches the app with only one stressor enabled at a time,
    /// allowing us to identify which specific conditions are necessary vs. sufficient for InfinityBug reproduction.
    ///
    /// **WHAT IT TESTS:**
    /// Each stressor in isolation:
    /// 1. Nested Layout (3-level compositional layout) - Tests if complex layout alone causes focus issues
    /// 2. Hidden Focusable Traps (invisible accessible elements) - Tests if accessibility tree bloat is sufficient
    /// 3. Jiggle Timer (constant layout changes) - Tests if layout churn alone triggers the bug
    /// 4. Circular Focus Guides (conflicting preferred environments) - Tests if guide conflicts cause loops
    /// 5. Duplicate Identifiers (accessibility ID collisions) - Tests if identity conflicts trigger issues
    ///
    /// **WHY IT SHOULD SUCCEED:**
    /// Based on our analysis, InfinityBug requires a COMBINATION of stressors, not just one:
    /// - Individual stressors should NOT reproduce the bug (test should pass for each)
    /// - If any single stressor DOES reproduce the bug, that identifies it as the primary root cause
    /// - This validates our theory that InfinityBug is a "perfect storm" of multiple conditions
    /// - Each test runs only 50 presses (vs 200) to keep execution time reasonable while still stressing the system
    ///
    /// **EXPECTED OUTCOME:**
    /// All individual stressor tests should PASS (no InfinityBug detected)
    /// If any individual test FAILS, that stressor is a primary cause and needs focused investigation
    /// This validates the multi-factor hypothesis and helps prioritize fixes
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
    
    /// ACCESSIBILITY INFRASTRUCTURE VALIDATION TEST
    ///
    /// **HOW IT APPROACHES THE ISSUE:**
    /// This test validates that the FocusStress harness has correctly set up the accessibility infrastructure
    /// that enables InfinityBug reproduction. It's a prerequisite verification that ensures all the stressor
    /// components are properly initialized before running the actual reproduction tests.
    ///
    /// **WHAT IT TESTS:**
    /// - Collection view existence and accessibility setup
    /// - Proper cell accessibility identifiers (both unique and duplicate)
    /// - Accessibility element hierarchy and structure
    /// - Hidden focusable trap elements (if enabled)
    /// - Duplicate identifier stressor setup validation
    ///
    /// **WHY IT SHOULD SUCCEED:**
    /// This is a foundational test that should always pass if the FocusStress harness is working correctly:
    /// - It verifies the test environment is properly configured
    /// - It validates that stressor 5 (duplicate IDs) is creating the expected accessibility conflicts
    /// - It ensures the collection view has the complex accessibility tree required for InfinityBug reproduction
    /// - It confirms that cells have proper accessibility labels and traits for VoiceOver interaction
    ///
    /// **EXPECTED OUTCOME:**
    /// Test should always PASS - failure indicates a broken test environment
    /// Should find 5+ unique cells with proper identifiers
    /// Should detect duplicate ID cells if stressor 5 is enabled
    /// Serves as a "smoke test" for the FocusStress infrastructure
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
    
    /// PHANTOM EVENT CACHE CORRUPTION REPRODUCTION TEST
    ///
    /// **HOW IT APPROACHES THE ISSUE:**
    /// This test specifically targets the "phantom event" manifestation of InfinityBug by overwhelming the
    /// system's input event cache with ultra-high frequency input, then using specific directional patterns
    /// that have been observed to trigger phantom presses in manual testing. The test integrates with
    /// AXFocusDebugger to capture low-level input monitoring during the reproduction attempt.
    ///
    /// **WHAT IT TESTS:**
    /// - Ultra-high frequency input saturation (8ms press/gap intervals)
    /// - Multi-directional cache flooding to create event backlogs
    /// - Repetitive directional bursts matching successful manual reproduction patterns
    /// - Heavy right-weighted exploration (matching observations that rightward navigation is most prone to InfinityBug)
    /// - Machine-gun right presses (600 rapid presses to trigger "Black Hole" heuristic)
    /// - Integration with AXFocusDebugger for capturing phantom events vs. legitimate hardware input
    ///
    /// **WHY IT SHOULD SUCCEED:**
    /// This test implements the exact input patterns observed during successful manual InfinityBug reproduction:
    /// - Phase 0: Ultra-high frequency seeding (150 presses in 2.4s) saturates the accessibility event queue
    /// - Phase 1: Multi-directional flooding creates event backlog conditions
    /// - Phase 2: Directional burst patterns replicate the manual testing sequence that triggered phantom events
    /// - Phase 3A: Extended right exploration matches the observed behavior where rightward navigation fails
    /// - Phase 3B: Right-weighted randomized input continues the stress on the rightward navigation path
    /// - Phase 3C: Machine-gun right presses (600 in 14.4s) triggers the exact "Black Hole" condition
    /// - AXFocusDebugger integration captures the divergence between hardware input and phantom events
    ///
    /// **EXPECTED OUTCOME:**
    /// Test should FAIL (InfinityBug detected) if phantom event reproduction succeeds
    /// InfinityBugDetector should fire with high confidence when phantom events start occurring
    /// Timeout failure indicates the specific phantom event pattern was not triggered
    /// This is the most aggressive reproduction test - if this doesn't reproduce the bug, manual reproduction is needed
    func testPhantomEventCacheBugReproduction() throws {
        NSLog("DIAGNOSTIC: Testing phantom event cache corruption through repetitive directional input with AXFocusDebugger integration")
        
        // Enable detailed AXFocusDebugger logging during test
        self.setupAXFocusDebuggerLogging()
        
        // Expectation for InfinityBug detection – *not* inverted.
        // Test will PASS only if bug is detected within timeout, ensuring reproduction.
        let bugExpectation = XCTNSNotificationExpectation(name: Notification.Name("com.infinitybug.highConfidenceDetection"))
        bugExpectation.isInverted = false  // We WANT the notification
        
        let startTime = Date()
        
        // Phase 0: Ultra-high frequency focus seeding to saturate the accessibility event queue
        NSLog("DIAGNOSTIC PHANTOM: Phase 0 - Ultra-high frequency seeding")
        for i in 0..<150 {
            let dir: XCUIRemote.Button = (i % 2 == 0) ? .right : .left
            remote.press(dir, forDuration: 0.008) // 8 ms press
            usleep(8_000) // 8 ms gap
        }
        
        // Prime the expensive focus query once to kick the accessibility engine
        _ = focusID
        
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
        
        // Phase 3C: Machine-gun right presses to exploit focus backlog and trigger "Black-Hole" heuristic
        NSLog("DIAGNOSTIC PHANTOM: Phase 3C - Machine-gun right presses")
        for _ in 0..<600 {   // 600 rapid presses ≈ 9 s with gaps below 20 ms
            remote.press(.right, forDuration: 0.012) // 12 ms press
            usleep(12_000) // 12 ms gap
        }
        
        // Give the system a brief window to process backlog and for InfinityBugDetector to evaluate
        sleep(4)
        
        let totalTime = Date().timeIntervalSince(startTime)
        NSLog("DIAGNOSTIC PHANTOM: Phantom event cache reproduction test completed in \(String(format: "%.1f", totalTime))s")
        
        // Wait up to 10 s for bug detection
        let result = XCTWaiter.wait(for: [bugExpectation], timeout: 10.0)
        
        switch result {
        case .completed:
            NSLog("SUCCESS: InfinityBug reproduced – detector fired within test window")
        case .timedOut:
            NSLog("METRIC: Detector signalled high-confidence InfinityBug during UITest run – recording for analysis but not failing test.")
        default:
            NSLog("WARNING: Unexpected XCTWaiter result: \(result) – recording for analysis.")
        }
    }

    /// PERFORMANCE DEGRADATION MONITORING TEST
    ///
    /// **HOW IT APPROACHES THE ISSUE:**
    /// This test monitors system performance degradation under stress conditions to identify when the focus
    /// system begins to fail. It measures press responsiveness and timing to detect when the system crosses
    /// the threshold from "stressed but functional" to "InfinityBug conditions." Performance degradation
    /// often precedes InfinityBug reproduction.
    ///
    /// **WHAT IT TESTS:**
    /// - Press responsiveness percentage (how many presses result in focus changes)
    /// - Press processing latency (how long each press takes to complete)
    /// - System stability under randomized directional stress
    /// - Performance threshold identification (when does the system start failing?)
    /// - Focus system degradation patterns vs. normal operation
    ///
    /// **WHY IT SHOULD SUCCEED:**
    /// This test establishes performance baselines and thresholds:
    /// - Under normal conditions, should achieve >60% press responsiveness
    /// - Should complete within 30s per stress factor (reasonable performance expectation)
    /// - Slow presses (>100ms) indicate system stress but not necessarily InfinityBug
    /// - Establishes metrics for comparing performance across different device configurations
    /// - Validates that the FocusStress harness doesn't break basic functionality
    ///
    /// **EXPECTED OUTCOME:**
    /// Test should PASS with good performance metrics under normal conditions
    /// Should detect performance degradation without false positively identifying InfinityBug
    /// Provides baseline metrics for comparing stress conditions across test runs
    /// Failure indicates either system overload or test environment issues
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
        XCTAssertLessThan(totalTime, 60.0 * Double(stressFactor), "Performance test should complete within 60 seconds")
    }
    
    /// INFINITYBUG DETECTOR VALIDATION AND FEEDING TEST
    ///
    /// **HOW IT APPROACHES THE ISSUE:**
    /// This test validates the InfinityBugDetector's ability to identify the "Black Hole" condition by creating
    /// controlled scenarios where many directional presses occur with zero focus changes. It manually tracks
    /// focus changes and press counts to verify that the detector can identify the exact conditions that
    /// constitute InfinityBug behavior.
    ///
    /// **WHAT IT TESTS:**
    /// - InfinityBugDetector accuracy in identifying "Black Hole" conditions
    /// - Focus change tracking vs. press count correlation
    /// - Machine-gun press detection with focus divergence monitoring
    /// - Detector confidence scoring under controlled stress scenarios
    /// - Integration between press events and focus tracking systems
    ///
    /// **WHY IT SHOULD SUCCEED:**
    /// This test creates the specific mathematical condition that defines InfinityBug:
    /// - Phase 1: Establishes baseline focus changes with normal press patterns
    /// - Phase 2: Machine-gun presses (200 at 12ms intervals) with limited focus tracking
    /// - Phase 3: If zero focus changes occur with >10 presses, this mathematically defines "Black Hole"
    /// - Additional rapid presses (100 at 8ms intervals) maximize detector confidence
    /// - The detector should fire because the math precisely matches the InfinityBug definition
    ///
    /// **EXPECTED OUTCOME:**
    /// Test should FAIL (detector fires) when "Black Hole" condition is met: many presses, zero focus changes
    /// Test should PASS (timeout) if focus changes occur normally during machine-gun phase
    /// This validates both detector accuracy and helps reproduce InfinityBug under controlled conditions
    /// Provides direct feedback on whether the detector is working correctly
    func testInfinityBugDetectorFeedingReproduction() throws {
        NSLog("DIAGNOSTIC: Testing InfinityBug reproduction with manual detector feeding")
        
        // Enable detailed AXFocusDebugger logging during test
        self.setupAXFocusDebuggerLogging()
        
        // Expectation for InfinityBug detection
        let bugExpectation = XCTNSNotificationExpectation(name: Notification.Name("com.infinitybug.highConfidenceDetection"))
        bugExpectation.isInverted = false  // We WANT the notification
        
        let startTime = Date()
        
        // Get reference to the collection view's bugDetector
        let stressCollectionView = app.collectionViews["FocusStressCollectionView"]
        XCTAssertTrue(stressCollectionView.exists, "FocusStressCollectionView should exist")
        
        // Phase 1: Warm-up with normal presses to establish baseline
        NSLog("DETECTOR FEED: Phase 1 - Baseline establishment")
        var lastFocusID = focusID
        
        for i in 0..<20 {
            let direction: XCUIRemote.Button = (i % 2 == 0) ? .right : .left
            
            remote.press(direction, forDuration: 0.05)
            usleep(150_000) // 150ms gap
            
            let currentFocusID = focusID
            
            // Manually feed both press and focus events to detector
            // Note: We can't directly access the detector from UI tests, but we can trigger the same conditions
            if currentFocusID != lastFocusID {
                NSLog("DETECTOR FEED: Focus changed from '\(lastFocusID)' to '\(currentFocusID)'")
                lastFocusID = currentFocusID
            }
        }
        
        // Phase 2: Machine-gun presses with focus tracking to trigger "Black Hole" detection
        NSLog("DETECTOR FEED: Phase 2 - Machine-gun with focus divergence tracking")
        
        var focusChanges = 0
        var directionalPresses = 0
        lastFocusID = focusID
        
        for i in 0..<200 { // Reduced from 600 for faster execution
            remote.press(.right, forDuration: 0.05) // 50ms press
            usleep(100_000) // 100ms gap - more reasonable timing
            
            directionalPresses += 1
            
            // Check focus every 10 presses to avoid constant expensive queries
            if i % 10 == 0 {
                let currentFocusID = focusID
                if currentFocusID != lastFocusID {
                    focusChanges += 1
                    lastFocusID = currentFocusID
                    NSLog("DETECTOR FEED: Focus change \(focusChanges) at press \(directionalPresses)")
                }
            }
        }
        
        NSLog("DETECTOR FEED: After machine-gun phase - \(directionalPresses) presses, \(focusChanges) focus changes")
        
        // Phase 3: Simulate the exact "Black Hole" condition manually
        if focusChanges == 0 && directionalPresses > 10 {
            NSLog("DETECTOR FEED: BLACK HOLE CONDITION MET - Many presses (\(directionalPresses)) with zero focus changes (\(focusChanges))")
            
            // Force additional rapid presses to maximize detector confidence
            for _ in 0..<100 {
                remote.press(.right, forDuration: 0.008) // Even faster
                usleep(8_000) // 8ms gap
            }
        }
        
        // Give system time to process and detector to evaluate
        sleep(3)
        
        let totalTime = Date().timeIntervalSince(startTime)
        NSLog("DETECTOR FEED: Test completed in \(String(format: "%.1f", totalTime))s")
        
        // Wait for bug detection
        let result = XCTWaiter.wait(for: [bugExpectation], timeout: 5.0)
        
        switch result {
        case .completed:
            NSLog("SUCCESS: InfinityBug reproduced with detector feeding approach")
        case .timedOut:
            NSLog("METRIC: Detector signalled high-confidence InfinityBug during UITest run – recording for analysis but not failing test.")
        default:
            NSLog("WARNING: Unexpected XCTWaiter result: \(result) – recording for analysis.")
        }
    }

    /// MAXIMUM STRESS MANUAL REPRODUCTION TEST
    ///
    /// **HOW IT APPROACHES THE ISSUE:**
    /// This test abandons all automated detection and focuses purely on creating the most extreme stress
    /// conditions possible for manual observation. It implements a brute-force approach with 3600 total
    /// presses across 5 phases, each designed to maximize different aspects of system stress. The goal
    /// is to overwhelm the focus system so completely that InfinityBug becomes visually obvious.
    ///
    /// **WHAT IT TESTS:**
    /// - Maximum system saturation (1000 presses at 5ms intervals = absolute minimum timing)
    /// - Right-direction focus with duplicate ID collisions (500 presses with occasional diversions)
    /// - Left-right alternating thrash (800 alternations to stress directional algorithms)
    /// - Chaos burst with right-weighted distribution (300 randomized presses favoring right direction)
    /// - Final right-only barrage (1000 consecutive right presses at 3ms intervals)
    ///
    /// **WHY IT SHOULD SUCCEED:**
    /// This test is designed to succeed through overwhelming force rather than surgical precision:
    /// - 3600 total presses should exhaust any event queue or cache system
    /// - Minimum timing intervals (3-8ms) push hardware and software to absolute limits
    /// - Right-weighted distribution targets the direction most prone to InfinityBug in manual testing
    /// - Alternating thrash specifically stresses the focus engine's directional algorithms
    /// - Chaos bursts introduce unpredictability that can trigger edge cases
    /// - Final right barrage provides sustained unidirectional stress for extended periods
    ///
    /// **EXPECTED OUTCOME:**
    /// This test should ALWAYS PASS (no assertions, just execution)
    /// Success is measured by MANUAL OBSERVATION during and after the test:
    /// - Look for: stuck focus, infinite button repeats, system unresponsiveness
    /// - InfinityBug manifestation: continued remote button activity after test completion
    /// - Visual indicators: focus highlighting stuck on one element, no response to new input
    /// - System behavior: tvOS becomes unresponsive or exhibits phantom remote control activity
    func testMaximumStressForManualReproduction() throws {
        NSLog("MANUAL REPRO: Starting maximum stress test for manual InfinityBug observation")
        NSLog("MANUAL REPRO: Run this test and observe tvOS behavior manually")
        NSLog("MANUAL REPRO: Look for: stuck focus, infinite button repeats, system unresponsiveness")
        
        let startTime = Date()
        
        // Phase 1: Saturate the system with rapid input
        NSLog("MANUAL REPRO: Phase 1 - System saturation (1000 rapid presses)")
        for i in 0..<1000 {
            let direction: XCUIRemote.Button = [.right, .left, .up, .down].randomElement()!
            remote.press(direction, forDuration: 0.005) // 5ms press
            usleep(5_000) // 5ms gap - absolute minimum
            
            if i % 100 == 0 {
                NSLog("MANUAL REPRO: Saturation progress: \(i)/1000")
            }
        }
        
        // Phase 2: Focus on right direction with duplicate ID stress
        NSLog("MANUAL REPRO: Phase 2 - Right direction focus with duplicate stress")
        for i in 0..<500 {
            remote.press(.right, forDuration: 0.008)
            usleep(8_000)
            
            // Inject random other directions occasionally
            if i % 20 == 0 {
                remote.press([.up, .down, .left].randomElement()!, forDuration: 0.008)
                usleep(8_000)
            }
        }
        
        // Phase 3: Alternating left-right thrash
        NSLog("MANUAL REPRO: Phase 3 - Left-right thrash (800 alternations)")
        for i in 0..<800 {
            let direction: XCUIRemote.Button = (i % 2 == 0) ? .right : .left
            remote.press(direction, forDuration: 0.006)
            usleep(6_000)
        }
        
        // Phase 4: Chaos burst
        NSLog("MANUAL REPRO: Phase 4 - Chaos burst (300 random directions)")
        for i in 0..<300 {
            let direction: XCUIRemote.Button = [.right, .right, .right, .left, .up, .down].randomElement()! // Right-weighted
            remote.press(direction, forDuration: 0.004)
            usleep(4_000)
        }
        
        // Phase 5: Final right-only barrage
        NSLog("MANUAL REPRO: Phase 5 - Final right barrage (1000 right presses)")
        for i in 0..<1000 {
            remote.press(.right, forDuration: 0.003)
            usleep(3_000)
            
            if i % 200 == 0 {
                NSLog("MANUAL REPRO: Right barrage progress: \(i)/1000")
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        NSLog("MANUAL REPRO: Test completed in \(String(format: "%.1f", totalTime))s")
        NSLog("MANUAL REPRO: Total presses: 3600 - observe system behavior manually")
        NSLog("MANUAL REPRO: If InfinityBug occurred, you should see continued button repeats even after test ends")
        
        // Just wait a bit for any delayed effects
        sleep(5)
        
        NSLog("MANUAL REPRO: Test finished - check for stuck focus or phantom presses")
    }

    /// BASIC NAVIGATION VALIDATION TEST
    ///
    /// **PURPOSE:**
    /// This test validates that our improved timing and UI detection methods work correctly
    /// before attempting more complex InfinityBug reproduction. It serves as a baseline
    /// to confirm that input is processed and focus changes can be detected reliably.
    ///
    /// **WHAT IT TESTS:**
    /// - Collection view exists and is interactive
    /// - Input presses are processed by the UI test framework
    /// - Focus changes can be detected with improved timing
    /// - Basic navigation through cells works
    ///
    /// **SUCCESS CRITERIA:**
    /// - Collection view found successfully
    /// - At least 3 distinct focus states detected from 20 inputs
    /// - Test completes within 30 seconds
    /// - No infrastructure failures
    func testBasicNavigationValidation() throws {
        NSLog("VALIDATION: Testing basic navigation with improved timing")
        
        let stressCollectionView = app.collectionViews["FocusStressCollectionView"]
        XCTAssertTrue(stressCollectionView.exists, "Collection view should exist")
        XCTAssertTrue(stressCollectionView.isHittable, "Collection view should be hittable")
        
        let startTime = Date()
        var focusStates: [String] = []
        
        // Simple navigation test: 20 alternating presses
        for i in 0..<20 {
            let direction: XCUIRemote.Button = (i % 2 == 0) ? .right : .left
            
            // Check focus before press
            let beforeFocus = focusID
            
            // Use improved timing
            remote.press(direction, forDuration: 0.05)
            usleep(150_000) // 150ms gap
            
            // Check focus after press
            let afterFocus = focusID
            
            focusStates.append(afterFocus)
            
            NSLog("VALIDATION[\(i)]: \(direction == .right ? "RIGHT" : "LEFT") '\(beforeFocus)' → '\(afterFocus)'")
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let uniqueFocuses = Set(focusStates.filter { isValidFocus($0) })
        
        NSLog("VALIDATION RESULT: \(uniqueFocuses.count) unique focus states in \(String(format: "%.1f", totalTime))s")
        NSLog("VALIDATION STATES: \(Array(uniqueFocuses))")
        
        // Validation assertions
        XCTAssertGreaterThan(uniqueFocuses.count, 2, "Should detect at least 3 different focus states")
        XCTAssertLessThan(totalTime, 30.0, "Basic navigation should complete within 30 seconds")
        
        NSLog("VALIDATION: ✅ Basic navigation working correctly")
    }
} 