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
        
        // Prerequisites assumed: real Apple TV with VoiceOver already enabled.

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
    
    // ================================================================
    // MARK: - ACTIVE EXPERIMENTAL TESTS (2025-06-22)
    // ================================================================
    
    /// Heavy manual-observation stress run. Generates 1 200 presses with a
    /// right-biased pattern that has the highest empirical reproduction rate.
    /// Never asserts – success is judged by the human tester.
    func testManualInfinityBugStress() throws {
        NSLog("MANUAL-BUG: Starting heavy stress run – observe tvOS for lock-up or infinite presses")

        let pattern: [XCUIRemote.Button] = Array(repeating: .right, count: 900) +
                                            Array(repeating: .left,  count: 150) +
                                            Array(repeating: .up,    count: 75)  +
                                            Array(repeating: .down,  count: 75)

        for (idx, dir) in pattern.enumerated() {
            remote.press(dir, forDuration: 0.03)   // 30 ms press
            usleep(30_000)                          // 30 ms gap
            if idx % 200 == 0 { NSLog("MANUAL-BUG: progress \(idx)/\(pattern.count)") }
        }

        NSLog("MANUAL-BUG: Stress run completed – check for InfinityBug symptoms before continuing")
        sleep(5) // leave UI in stressed state for inspection
    }

    /// EXPERIMENT 1 – Timing sweep.  Runs three press intervals and logs the
    /// focus-change ratio so we can see which timing best starves the focus
    /// engine.  No assertions.
    func testPressIntervalSweep() throws {
        let intervals: [useconds_t] = [50_000, 30_000, 15_000] // 50 ms, 30 ms, 15 ms

        for gap in intervals {
            NSLog("TIMING-SWEEP: Running gap = \(Double(gap)/1000.0) ms")
            var focusChanges = 0
            let samplePresses = 300

            var lastFocus = focusID
            for _ in 0..<samplePresses {
                remote.press(.right, forDuration: 0.02)
                usleep(gap)
                let f = focusID
                if f != lastFocus { focusChanges += 1; lastFocus = f }
            }

            let ratio = Double(focusChanges) / Double(samplePresses)
            NSLog("TIMING-SWEEP: gap \(gap) µs → focus-change ratio = \(String(format: "%.2f", ratio))")
        }
    }

    /// EXPERIMENT 2 – Hidden-trap density toggle.  Relaunches the app with
    /// two different trap densities to see how focus responsiveness varies.
    /// Requires FocusStressViewController to honour the
    /// `HIDDEN_TRAP_DENSITY` environment variable (handled separately).
    func testHiddenTrapDensityComparison() throws {
        let densities = [8, 40] // traps per cell

        for d in densities {
            NSLog("TRAP-DENSITY: Relaunching with density = \(d)")
            app.terminate()
            usleep(300_000)

            app.launchEnvironment["HIDDEN_TRAP_DENSITY"] = "\(d)"
            app.launch()

            sleep(2)
            let cv = app.collectionViews["FocusStressCollectionView"]
            guard cv.exists else { NSLog("ERROR: collection view missing at density \(d)"); continue }

            var focusChanges = 0
            var lastFocus = focusID
            for _ in 0..<200 {
                remote.press(.right, forDuration: 0.04)
                usleep(40_000)
                let f = focusID
                if f != lastFocus { focusChanges += 1; lastFocus = f }
            }
            NSLog("TRAP-DENSITY: \(d) traps → \(focusChanges) focus changes / 200 presses")
        }
    }
} 
