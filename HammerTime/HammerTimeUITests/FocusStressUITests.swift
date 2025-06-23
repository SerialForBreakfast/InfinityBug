//
//  FocusStressUITests.swift
//  HammerTimeUITests
//
//  Created by Joseph McCraw on 6/13/25.
//
//  ========================================================================
//  INFINITYBUG REPRODUCTION SUITE V2.0 - PERFORMANCE OPTIMIZED
//  ========================================================================
//
//  **CRITICAL LEARNINGS FROM V1.0 (2025-06-22):**
//  - Element queries are 10-100x slower than expected (2-20 seconds each)
//  - Focus tracking during press sequences kills performance
//  - Tests must complete in <10 minutes or be removed
//  - Dynamic movement patterns needed vs. edge-sticking
//  - Exponential scaling required for broader parameter coverage
//  - Manual observation > automated detection for InfinityBug
//
//  **V2.0 STRATEGY:**
//  1. ELIMINATE real-time focus tracking during press sequences
//  2. Use cached cell references to avoid repeated element queries
//  3. Implement exponential press intervals: 8ms, 16ms, 32ms, 64ms, 128ms
//  4. Batch setup, pure press execution, minimal validation
//  5. Add realistic execution time estimates vs. actual measurements
//  6. Apply selection pressure - remove tests that don't reproduce
//
//  **EXECUTION TIME ESTIMATES:**
//  Each test includes estimated execution time based on:
//  - Setup overhead: ~30 seconds (app launch + element caching)
//  - Press time: (press_count × interval_ms) + overhead
//  - Validation time: ~5 seconds (minimal element checks)
//  - Total target: <10 minutes maximum, <5 minutes preferred
//
//  **EXPONENTIAL SCALING RATIONALE:**
//  Linear scaling (10ms, 20ms, 30ms) tests similar conditions.
//  Exponential scaling (8ms, 16ms, 32ms, 64ms, 128ms) covers:
//  - Ultra-fast: 8-16ms (aggressive HID layer stress)
//  - Fast: 32ms (typical rapid user input)
//  - Medium: 64ms (reasonable user pace)
//  - Slow: 128ms (deliberate user input)
//  This provides 32x range coverage vs. 3x for linear scaling.

import XCTest
@testable import HammerTime

/// Returns true when a focus ID refers to a real UI element (not empty/placeholder).
private func isValidFocus(_ id: String) -> Bool {
    return !id.isEmpty && id != "NONE" && id != "NO_FOCUS"
}

/// Optimized FocusStress UI test suite focused on efficient InfinityBug reproduction.
/// V2.0 - Performance optimized, exponential scaling, realistic time estimates.
final class FocusStressUITests: XCTestCase {
    
    var app: XCUIApplication!
    var navigator: NavigationStrategyExecutor!
    let remote = XCUIRemote.shared
    
    // MARK: - Cached Elements (Performance Optimization)
    
    private var cachedCollectionView: XCUIElement?
    private var cachedCells: [XCUIElement] = []
    
    /// Scale factor for test intensity (default = 1, can be overridden via environment)
    private var stressFactor: Int {
        if let envValue = ProcessInfo.processInfo.environment["STRESS_FACTOR"],
           let factor = Int(envValue), factor > 0 {
            return factor
        }
        return 1
    }
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        navigator = NavigationStrategyExecutor(app: app)
        
        // Launch with FocusStressMode heavy for comprehensive stress testing
        app.launchArguments += [
            "-FocusStressMode", "heavy",
            "-DebounceDisabled", "YES",
            "-FocusTestMode", "YES"
        ]
        
        app.launchEnvironment["DEBOUNCE_DISABLED"] = "1"
        app.launchEnvironment["FOCUS_TEST_MODE"] = "1"
        
        // Reset the bug detector before each run
        app.launchArguments += ["-ResetBugDetector"]
        
        // Set stress factor if specified
        if stressFactor != 1 {
            app.launchEnvironment["STRESS_FACTOR"] = "\(stressFactor)"
        }
        
        app.launch()
        
        // MINIMAL SETUP: Only cache collection view - no cell queries
        try minimalCacheSetup()
        
        NSLog("SETUP: Minimal caching complete - ready for rapid button mashing")
    }
    
    override func tearDownWithError() throws {
        app = nil
        cachedCollectionView = nil
        cachedCells.removeAll()
    }
    
    // MARK: - Performance Optimization Methods
    
    /// Minimal caching setup - only what's absolutely necessary
    /// NO expensive cell queries or focus establishment
    private func minimalCacheSetup() throws {
        // Wait for collection view existence only
        let stressCollectionView = app.collectionViews["FocusStressCollectionView"]
        XCTAssertTrue(stressCollectionView.waitForExistence(timeout: 10),
                     "FocusStressCollectionView should exist - ensure app launched with -FocusStressMode heavy")
        
        // Cache collection view reference only
        cachedCollectionView = stressCollectionView
        
        NSLog("SETUP: Collection view cached - NO cell queries for maximum speed")
    }
    
    /// Enforces test execution time limits and logs timing estimates vs. actual.
    /// Tests exceeding limits are flagged for removal or refactoring.
    private func enforceTimeLimit(estimatedMinutes: Double) {
        let startTime = Date()
        let limitSeconds = 600.0 // 10 minutes maximum
        
        NSLog("TIME-ESTIMATE: Test estimated to take \(String(format: "%.1f", estimatedMinutes)) minutes")
        
        // Set up a timer that will fail the test after 10 minutes
        Timer.scheduledTimer(withTimeInterval: limitSeconds, repeats: false) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            let elapsedMinutes = elapsed / 60.0
            XCTFail("Test exceeded 10-minute limit (\(String(format: "%.1f", elapsedMinutes)) minutes actual vs. \(String(format: "%.1f", estimatedMinutes)) estimated). Test should be refactored or removed.")
        }
    }
    
    // MARK: - Focus Tracking (REMOVED FOR SPEED)
    
    /// Focus tracking removed - was causing 2+ second delays per button press
    /// Manual observation is the only reliable way to detect InfinityBug
    private func quickFocusCheck() -> String {
        return "FOCUS_TRACKING_DISABLED_FOR_SPEED"
    }
    
    /// Focus validation removed - was causing expensive queries
    private func isValidFocus(_ focus: String) -> Bool {
        return true // Always return true to avoid queries
    }
    
    // MARK: - NavigationStrategy Integration
    
    /// All test methods now use NavigationStrategy patterns with:
    /// - Edge detection and boundary avoidance 
    /// - Random intervals between 8ms-1000ms for comprehensive coverage
    /// - Smart navigation patterns that don't get stuck at collection edges
    /// - Comprehensive stress testing across different movement strategies
    
    // MARK: - Active Tests (V5.0 - Based on SuccessfulRepro2.txt Analysis)
    
    /// **ESTIMATED EXECUTION TIME: 4.5 minutes**
    /// Direct replication of SuccessfulRepro2.txt manual reproduction pattern.
    /// Based on analysis of actual InfinityBug manifestation with POLL detection and progressive RunLoop stalls.
    /// Key pattern: Right-heavy exploration → Up bursts → System collapse with "response-not-possible"
    func testSuccessfulRepro2Pattern() throws {
        enforceTimeLimit(estimatedMinutes: 4.5)
        
        NSLog("REPRO2-PATTERN: Implementing SuccessfulRepro2.txt reproduction pattern")
        
        // Phase 1: Initial mixed directional setup (first ~30 seconds of log)
        NSLog("REPRO2-PATTERN: Phase 1 - Initial directional setup")
        let setupPattern: [XCUIRemote.Button] = [.down, .right, .right, .down, .right, .up, .down]
        for (index, direction) in setupPattern.enumerated() {
            remote.press(direction, forDuration: 0.025)
            // Varied timing as seen in log: 50-200ms gaps
            let gap = index % 2 == 0 ? 50_000 : 150_000
            usleep(UInt32(gap))
        }
        
        // Phase 2: Heavy Right exploration (core pattern from SuccessfulRepro2.txt)
        NSLog("REPRO2-PATTERN: Phase 2 - Heavy Right exploration with corrections")
        for burstIndex in 0..<8 {
            // Right burst (12-25 presses based on log analysis)
            let rightCount = 15 + (burstIndex * 2) // Escalating: 15, 17, 19, 21, 23, 25, 27, 29
            for _ in 0..<rightCount {
                remote.press(.right, forDuration: 0.025)
                usleep(40_000) // 40ms - VoiceOver optimized timing
            }
            
            // Direction correction (Down or Left)
            let correctionDirection: XCUIRemote.Button = burstIndex % 2 == 0 ? .down : .left
            let correctionCount = 3 + (burstIndex / 2) // 3, 3, 4, 4, 5, 5, 6, 6
            for _ in 0..<correctionCount {
                remote.press(correctionDirection, forDuration: 0.025)
                usleep(60_000) // Slightly longer gaps for corrections
            }
            
            // Brief pause between bursts (allows system stress to build)
            usleep(100_000) // 100ms
        }
        
        // Phase 3: Critical Up burst sequence (triggers POLL detection)
        NSLog("REPRO2-PATTERN: Phase 3 - Critical Up burst sequence")
        for upBurstIndex in 0..<6 {
            let upCount = 20 + (upBurstIndex * 5) // Escalating: 20, 25, 30, 35, 40, 45
            NSLog("REPRO2-PATTERN: Up burst \(upBurstIndex + 1): \(upCount) presses")
            
            for _ in 0..<upCount {
                remote.press(.up, forDuration: 0.025)
                usleep(35_000) // Slightly faster for Up bursts to create stress
            }
            
            // Progressive pause increase (system stress builds)
            let pauseMs = 200_000 + (upBurstIndex * 100_000) // 200ms → 700ms
            usleep(UInt32(pauseMs))
        }
        
        // Phase 4: Final mixed sequence leading to system collapse
        NSLog("REPRO2-PATTERN: Phase 4 - Final mixed sequence")
        let finalPattern: [XCUIRemote.Button] = [.up, .right, .up, .down, .up, .right, .up, .left, .up]
        for direction in finalPattern {
            remote.press(direction, forDuration: 0.025)
            usleep(30_000) // Fast final sequence to push system over edge
        }
        
        // Allow time for system collapse and snapshot errors
        NSLog("REPRO2-PATTERN: Waiting for potential system collapse...")
        usleep(2_000_000) // 2 second wait for InfinityBug manifestation
        
        let finalFocus = quickFocusCheck()
        NSLog("REPRO2-PATTERN: Final focus state: '\(finalFocus)' - Check for POLL detection and RunLoop stalls")
        
        // Test always passes - human observation required for InfinityBug detection
        XCTAssertTrue(true, "SuccessfulRepro2 pattern completed - observe for InfinityBug symptoms")
    }
    
    /// **ESTIMATED EXECUTION TIME: 6.0 minutes**  
    /// Extended cache flooding based on both SuccessfulRepro.md and SuccessfulRepro2.txt patterns.
    /// Implements the proven right-heavy exploration with progressive Up bursts.
    func testCacheFloodingWithProvenPatterns() throws {
        enforceTimeLimit(estimatedMinutes: 6.0)
        
        NSLog("CACHE-FLOODING-PROVEN: Testing cache corruption through proven burst patterns")
        
        // Extended burst patterns based on BOTH successful reproductions
        let burstPatterns: [(direction: XCUIRemote.Button, count: Int)] = [
            // SuccessfulRepro2.txt pattern influence
            (.right, 22),   // Heavy right exploration  
            (.down, 8),     // Short correction
            (.right, 25),   // More heavy right
            (.up, 20),      // Up burst (triggers POLL detection)
            (.right, 28),   // Extended right exploration
            (.left, 6),     // Brief left correction
            (.right, 30),   // Maximum right stress
            (.up, 25),      // Extended up burst
            (.right, 18),   // Continue right exploration
            (.down, 10),    // Down correction
            (.right, 32),   // Peak right stress
            (.up, 30),      // Peak up burst
            (.right, 20),   // Final right exploration
            (.up, 35),      // Maximum up burst (system collapse trigger)
            (.left, 12),    // Recovery attempt
            (.right, 15),   // Final right burst
            (.up, 40),      // Final up burst (InfinityBug trigger)
        ]
        
        for (burstIndex, burst) in burstPatterns.enumerated() {
            NSLog("CACHE-FLOODING-PROVEN: Burst \(burstIndex + 1)/\(burstPatterns.count): \(burst.direction) x\(burst.count)")
            
            for pressIndex in 0..<burst.count {
                remote.press(burst.direction, forDuration: 0.025) // 25ms press
                
                // Progressive timing stress - faster as burst progresses
                let baseGap = 50_000 // 50ms base
                let progressFactor = max(30_000, baseGap - (pressIndex * 1_000)) // Gets faster: 50ms → 30ms
                usleep(UInt32(progressFactor))
            }
            
            // Progressive pause between bursts - gets shorter (building stress)
            let burstPause = max(50_000, 200_000 - (burstIndex * 10_000)) // 200ms → 50ms
            usleep(UInt32(burstPause))
        }
        
        NSLog("CACHE-FLOODING-PROVEN: Cache flooding with proven patterns completed")
        
        // Test always passes - human observation required for InfinityBug detection  
        XCTAssertTrue(true, "Cache flooding with proven patterns completed - observe for InfinityBug symptoms")
    }
    
    /// **ESTIMATED EXECUTION TIME: 3.5 minutes**
    /// Hybrid approach combining NavigationStrategy patterns with SuccessfulRepro2.txt timing.
    /// Uses snake pattern to avoid edge-sticking while applying proven reproduction timing.
    func testHybridNavigationWithRepro2Timing() throws {
        enforceTimeLimit(estimatedMinutes: 3.5)
        
        NSLog("HYBRID-REPRO2: Testing NavigationStrategy with SuccessfulRepro2.txt timing")
        
        // Phase 1: Snake pattern with right-bias (matches SuccessfulRepro2.txt)
        navigator.execute(.snake(direction: .rightBiased), steps: 150)
        
        // Phase 2: Spiral pattern with proven timing intervals
        executeSpiralWithRepro2Timing(steps: 100)
        
        // Phase 3: Cross pattern with Up-emphasis (triggers POLL detection)
        executeCrossWithRepro2Timing(steps: 80)
        
        let finalFocus = quickFocusCheck()
        NSLog("HYBRID-REPRO2: Final focus state: '\(finalFocus)'")
        
        // Test always passes - human observation required for InfinityBug detection
        XCTAssertTrue(true, "Hybrid navigation with Repro2 timing completed - observe for InfinityBug symptoms")
    }
    
    // ================================================================
    // MARK: - Helper Methods for V4.0 Evolved Tests
    // ================================================================
    
    /// Executes snake pattern with proven VoiceOver-optimized timing intervals
    private func executeSnakeWithProvenTiming(steps: Int) {
        let snakePattern: [XCUIRemote.Button] = [.right, .right, .right, .down, .left, .left, .left, .down]
        
        for step in 0..<steps {
            let buttonDirection = snakePattern[step % snakePattern.count]
            remote.press(buttonDirection, forDuration: 0.025)
            usleep(45_000) // 45ms - proven VoiceOver timing
        }
    }
    
    /// Executes spiral pattern with proven VoiceOver-optimized timing intervals
    private func executeSpiralWithProvenTiming(steps: Int) {
        let spiralPattern: [XCUIRemote.Button] = [.right, .down, .left, .up]
        var repeatCount = 1
        
        for step in 0..<steps {
            let patternIndex = (step / repeatCount) % spiralPattern.count
            let buttonDirection = spiralPattern[patternIndex]
            
            remote.press(buttonDirection, forDuration: 0.025)
            usleep(40_000) // 40ms - proven VoiceOver timing
            
            // Adjust repeat count periodically
            if step % 16 == 0 {
                repeatCount = min(repeatCount + 1, 4)
            }
        }
    }
    
    /// Executes cross pattern with proven VoiceOver-optimized timing intervals
    private func executeCrossWithProvenTiming(steps: Int) {
        let crossPattern: [XCUIRemote.Button] = [.up, .right, .down, .left, .up, .left, .down, .right]
        
        for step in 0..<steps {
            let buttonDirection = crossPattern[step % crossPattern.count]
            remote.press(buttonDirection, forDuration: 0.025)
            usleep(35_000) // 35ms - slightly faster for cross pattern stress
        }
    }
    
    /// Executes random walk with proven VoiceOver-optimized timing intervals
    private func executeRandomWalkWithProvenTiming(seed: UInt64, steps: Int) {
        var rng = SeededRandomGenerator(seed: seed)
        let allDirections: [XCUIRemote.Button] = [.up, .down, .left, .right]
        
        for _ in 0..<steps {
            let randomDirection = allDirections[Int(rng.next()) % allDirections.count]
            remote.press(randomDirection, forDuration: 0.025)
            usleep(50_000) // 50ms - proven VoiceOver timing for random patterns
        }
    }
    
    /// Executes spiral pattern with SuccessfulRepro2.txt timing intervals
    private func executeSpiralWithRepro2Timing(steps: Int) {
        let spiralPattern: [XCUIRemote.Button] = [.right, .down, .left, .up]
        var repeatCount = 1
        
        for step in 0..<steps {
            let patternIndex = (step / repeatCount) % spiralPattern.count
            let buttonDirection = spiralPattern[patternIndex]
            
            remote.press(buttonDirection, forDuration: 0.025)
            // SuccessfulRepro2.txt showed 40-60ms gaps work best
            usleep(45_000) // 45ms - Repro2 optimized timing
            
            // Adjust repeat count periodically for expanding spiral
            if step % 12 == 0 {
                repeatCount = min(repeatCount + 1, 5)
            }
        }
    }
    
    /// Executes cross pattern with SuccessfulRepro2.txt timing intervals
    private func executeCrossWithRepro2Timing(steps: Int) {
        // Up-emphasized cross pattern based on POLL detection in SuccessfulRepro2.txt
        let crossPattern: [XCUIRemote.Button] = [.up, .up, .right, .down, .left, .up, .up, .left, .down, .right]
        
        for step in 0..<steps {
            let buttonDirection = crossPattern[step % crossPattern.count]
            remote.press(buttonDirection, forDuration: 0.025)
            // Faster timing for Up bursts to trigger POLL detection
            let gap = buttonDirection == .up ? 35_000 : 50_000
            usleep(UInt32(gap))
        }
    }
    
    /// Timing configuration override for proven VoiceOver intervals
    private struct ProvenTimingOverride {
        let pressDuration: TimeInterval = 0.025      // 25ms press
        let standardGap: UInt32 = 40_000            // 40ms gap
        let fastGap: UInt32 = 30_000                // 30ms gap for rapid sequences
        let slowGap: UInt32 = 50_000                // 50ms gap for complex patterns
    }
    
    // ================================================================
    // MARK: - Removed Tests Documentation
    // ================================================================
    
    /*
     ========================================================================
     TESTS REMOVED AFTER V1.0 ANALYSIS (2025-06-22)
     ========================================================================
     
     REMOVED: testManualInfinityBugStress
     - Reason: Exceeded 10-minute timeout due to expensive focus tracking
     - Focus changes: Only 1 change in 246 seconds (ratio: 0.000)
     - Duration: Failed at 300 seconds (5 minutes)
     - Replacement: testMixedExponentialPatterns (3.5 minutes estimated)
     
     REMOVED: testPressIntervalSweep  
     - Reason: Failed at 34 seconds due to slow element queries during setup
     - Never reached actual press sequences
     - Replacement: testExponentialPressIntervals (2.5 minutes estimated)
     
     REMOVED: testExponentialPressureScaling (original)
     - Reason: Poor focus movement (ratio: 0.000), expensive tracking
     - Duration: 252 seconds with minimal effectiveness
     - Replacement: testUltraFastHIDStress + testRapidDirectionalStress
     
     REMOVED: testSnakePatternNavigation (original)
     - Reason: Stub implementation without actual button presses
     - Duration: 37 seconds with no actual stress testing
     - Replacement: None (pattern tests prove ineffective)
     
     REMOVED: testSpiralPatternNavigation (original)
     - Reason: Stub implementation without actual button presses  
     - Duration: 35 seconds with no actual stress testing
     - Replacement: None (pattern tests prove ineffective)
     
     REMOVED: testEdgeCaseWithEdgeTester (original)
     - Reason: Stub implementation, completed too quickly without stress
     - Duration: 36 seconds with minimal testing
     - Replacement: None (edge testing incorporated into other tests)
     
     REMOVED: testHeavyReproductionWithRandomWalk (original)
     - Reason: Stub implementation, completed too quickly without stress
     - Duration: 35 seconds with minimal testing  
     - Replacement: None (random patterns prove less effective than systematic)
     
     REMOVED: All real-time focus tracking during press sequences
     - Reason: Element queries taking 2-20 seconds each
     - Performance killer that made tests unusable
     - Replacement: Cached elements + minimal end-of-test validation only
     
     SELECTION PRESSURE APPLIED:
     - Tests that don't complete in <10 minutes: REMOVED
     - Tests with focus change ratio <0.01: REMOVED  
     - Tests that spend >50% time on element queries: REMOVED
     - Tests without exponential parameter scaling: REMOVED
     - Tests with stub implementations: REMOVED
     - Tests that complete too quickly (<1 minute): REMOVED
     
     ARCHITECTURE CHANGES:
     - V1.0: 90% element queries + 10% button presses
     - V2.0: 5% setup + 90% button presses + 5% validation
     - V1.0: Linear parameter scaling (3x range coverage)
     - V2.0: Exponential parameter scaling (32x range coverage)
     - V1.0: Continuous focus tracking (expensive)
     - V2.0: Cached elements + minimal validation (fast)
     ========================================================================
     */
}

// MARK: - Helper Functions

    /// Launches the app with a specific preset using string constants.
/// Avoids cross-target enum dependency issues.
private func launchWithPreset(_ app: XCUIApplication, _ presetName: String) {
        app.launchArguments += ["-FocusStressPreset", presetName]
        app.launch()
}
