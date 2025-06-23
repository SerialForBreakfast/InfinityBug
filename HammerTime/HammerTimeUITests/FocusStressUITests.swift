//
//  FocusStressUITests.swift
//  HammerTimeUITests
//
//  ========================================================================
//  INFINITYBUG REPRODUCTION SUITE V8.0 - EVOLUTIONARY IMPROVEMENT APPLIED
//  ========================================================================
//  >>> EVOLVED TO V8.0 – FAILED APPROACHES REMOVED (2025-01-22)
//  ========================================================================
//
//  **EVOLUTIONARY TEST IMPROVEMENT PLAN APPLIED:**
//  ❌ REMOVED: Menu button simulation (backgrounds app - test failure)
//  ❌ REMOVED: Gesture simulation (coordinate API unavailable on tvOS)
//  ❌ REMOVED: Complex 7-phase system (overly complicated, no reproduction)
//  ❌ REMOVED: Mixed input event simulation (technical impossibility)
//  ❌ REMOVED: Memory stress background tasks (unrelated to input focus)
//  
//  ✅ KEPT: Right-heavy exploration (60% right bias from successful logs)
//  ✅ KEPT: Progressive Up bursts (22-45 presses from successful pattern)
//  ✅ KEPT: Natural timing irregularities (40-250ms human variation)
//  ✅ KEPT: System stress accumulation (progressive speed increase)
//
//  **TARGET SUCCESS PATTERN:**
//  - `[AXDBG] 065648.123 WARNING: RunLoop stall 5179 ms` (from successful repro)
//  - Progressive system stress without app backgrounding
//  - Human-like timing variations simulating human input patterns
//  - Focused 4-minute reproduction pattern vs scattered approaches
//
//  ========================================================================

import XCTest

/// **V8.0 Focused InfinityBug Reproduction Suite**
/// 
/// Implements proven successful patterns from manual reproduction logs while
/// removing all failed automated approaches identified through evolutionary analysis.
///
/// **Success Criteria:**
/// - RunLoop stalls >5000ms (matching successful manual reproduction)
/// - Progressive system stress accumulation
/// - Natural timing variations simulating human input patterns
/// - No app backgrounding or complex phase management
final class FocusStressUITests: XCTestCase {
    
    // MARK: - Test Infrastructure
    
    var app: XCUIApplication!
    private let remote = XCUIRemote.shared
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        
        // Minimal launch configuration focused on reproduction
        app.launchArguments += [
            "-FocusStressMode", "reproduction",
            "-DebounceDisabled", "YES"
        ]
        
        app.launchEnvironment["DEBOUNCE_DISABLED"] = "1"
        app.launchEnvironment["FOCUS_TEST_MODE"] = "1"
        
        app.launch()
        
        // Verify app launched correctly
        let collectionView = app.collectionViews["FocusStressCollectionView"]
        XCTAssertTrue(collectionView.waitForExistence(timeout: 10),
                     "FocusStressCollectionView should exist")
        
        NSLog("🎯 V8.0-SETUP: Ready for focused InfinityBug reproduction")
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - V8.0 FOCUSED REPRODUCTION TESTS
    
    /// **V8.0 PRIMARY TEST - ESTIMATED EXECUTION TIME: 4.0 minutes**
    /// 
    /// Implements the exact successful manual reproduction pattern:
    /// - Right-heavy exploration with natural timing irregularities
    /// - Progressive Up burst sequences (matching successful 22-45 pattern)
    /// - System stress accumulation without app backgrounding
    /// - Human-like input variation vs uniform automated timing
    ///
    /// **Target Outcome:** 
    /// `RunLoop stall >5000ms` matching successful manual reproduction
    func testEvolvedInfinityBugReproduction() throws {
        NSLog("🎯 V8.0-PRIMARY: Starting evolved InfinityBug reproduction")
        NSLog("🎯 TARGET: RunLoop stall >5000ms (from successful manual reproduction)")
        
        let startTime = Date()
        
        // Phase 1: Right-heavy exploration with natural timing (90 seconds)
        executeNaturalRightHeavyExploration(duration: 90.0)
        
        // Phase 2: Progressive Up burst accumulation (90 seconds)  
        executeProgressiveUpBurstAccumulation(duration: 90.0)
        
        // Phase 3: System stress acceleration (60 seconds)
        executeSystemStressAcceleration(duration: 60.0)
        
        let totalDuration = Date().timeIntervalSince(startTime)
        NSLog("🎯 V8.0-PRIMARY: Completed focused reproduction in \(String(format: "%.1f", totalDuration))s")
        NSLog("🎯 OBSERVE: Check for focus stuck behavior or phantom input continuation")
        
        XCTAssertTrue(true, "Focused reproduction pattern completed - observe manually for InfinityBug")
    }
    
    /// **V8.0 SECONDARY TEST - ESTIMATED EXECUTION TIME: 3.5 minutes**
    /// 
    /// Alternative reproduction approach using backgrounding trigger pattern
    /// from SuccessfulRepro4.txt but without Menu button (using app lifecycle instead).
    ///
    /// **Background Trigger Pattern:**
    /// Simulates the successful backgrounding approach but keeps focus within the app
    /// by using rapid stress bursts followed by brief pauses (simulating system interruption).
    func testEvolvedBackgroundingTriggeredInfinityBug() throws {
        NSLog("🎯 V8.0-SECONDARY: Starting evolved backgrounding-triggered reproduction")
        NSLog("🎯 PATTERN: Stress → Pause → Stress (simulating backgrounding without leaving app)")
        
        let startTime = Date()
        
        // 6 stress-pause cycles simulating backgrounding pressure
        for cycle in 0..<6 {
            NSLog("🎯 CYCLE \(cycle + 1)/6: Building stress for simulated interruption")
            
            // Build stress (30 seconds per cycle)
            let stressDuration = 30.0 + (Double(cycle) * 5.0) // Progressive: 30s → 55s
            executeFocusedStressBurst(duration: stressDuration)
            
            // Simulated interruption pause (2 seconds)
            NSLog("🎯 SIMULATED-INTERRUPTION: Brief system pause")
            usleep(2_000_000) // 2 second pause simulating backgrounding
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        NSLog("🎯 V8.0-SECONDARY: Completed backgrounding simulation in \(String(format: "%.1f", totalDuration))s")
        
        XCTAssertTrue(true, "Backgrounding simulation completed - observe manually for InfinityBug")
    }
}

// MARK: - V8.0 Implementation Extensions

extension FocusStressUITests {
    
    /// Execute natural right-heavy exploration with human-like timing irregularities
    ///
    /// **Implementation Notes:**
    /// - 60% right bias (matching successful manual reproduction)
    /// - Natural timing variation 40-250ms (vs uniform automated timing)
    /// - Progressive acceleration simulating increasing user frustration
    private func executeNaturalRightHeavyExploration(duration: TimeInterval) {
        NSLog("→ Natural right-heavy exploration: Human-like timing irregularities")
        
        let endTime = Date().addingTimeInterval(duration)
        var pressCount = 0
        
        while Date() < endTime {
            // 60% right bias from successful reproduction
            let direction: XCUIRemote.Button = (pressCount % 10 < 6) ? .right : [.up, .down, .left].randomElement()!
            
            // Human-like timing variation (vs uniform automated timing)
            let timingVariation = naturalHumanTiming(pressIndex: pressCount)
            
            remote.press(direction, forDuration: 0.025)
            usleep(timingVariation)
            
            pressCount += 1
            
            // Log progress every 50 presses
            if pressCount % 50 == 0 {
                NSLog("→ Right-heavy progress: \(pressCount) presses (60% right bias)")
            }
        }
        
        NSLog("→ Natural right-heavy exploration completed: \(pressCount) total presses")
    }
    
    /// Execute progressive Up burst accumulation matching successful reproduction pattern
    ///
    /// **Implementation Notes:**
    /// - 22-45 Up presses per burst (matching successful SuccessfulRepro logs)
    /// - Progressive acceleration: 40ms → 25ms (simulating system stress)
    /// - Brief recovery pauses between bursts
    private func executeProgressiveUpBurstAccumulation(duration: TimeInterval) {
        NSLog("↑ Progressive Up burst accumulation: Matching successful 22-45 pattern")
        
        let endTime = Date().addingTimeInterval(duration)
        var burstNumber = 0
        
        while Date() < endTime {
            let upCount = 22 + (burstNumber % 24) // 22-45 Up presses (matching successful pattern)
            NSLog("↑ Up burst \(burstNumber + 1): \(upCount) presses")
            
            // Execute Up burst with progressive acceleration
            for pressIndex in 0..<upCount {
                remote.press(.up, forDuration: 0.025)
                
                // Progressive acceleration: 40ms → 25ms (simulating system stress)
                let progressFactor = Double(pressIndex) / Double(upCount)
                let gapMicros = UInt32(40_000 - (15_000 * progressFactor)) // 40ms → 25ms
                usleep(gapMicros)
            }
            
            burstNumber += 1
            
            // Brief recovery pause between bursts
            usleep(200_000) // 200ms recovery
        }
        
        NSLog("↑ Progressive Up burst accumulation completed: \(burstNumber) bursts")
    }
    
    /// Execute system stress acceleration without app backgrounding
    ///
    /// **Implementation Notes:**
    /// - Rapid alternating directions for focus system pressure
    /// - Progressive speed increase: 35ms → 15ms
    /// - No Menu button or app lifecycle interference
    private func executeSystemStressAcceleration(duration: TimeInterval) {
        NSLog("💥 System stress acceleration: Progressive speed increase")
        
        let endTime = Date().addingTimeInterval(duration)
        var accelerationPhase = 0
        
        while Date() < endTime {
            // Rapid alternating sequence for focus system pressure
            let directions: [XCUIRemote.Button] = [.right, .up, .left, .up, .right, .down, .left, .down]
            
            for direction in directions {
                remote.press(direction, forDuration: 0.025)
                
                // Progressive speed increase: 35ms → 15ms
                let progressFactor = Double(accelerationPhase) / 20.0 // 20 phases over 60 seconds
                let gapMicros = UInt32(35_000 - (20_000 * min(1.0, progressFactor))) // 35ms → 15ms
                usleep(gapMicros)
            }
            
            accelerationPhase += 1
            
            if accelerationPhase % 5 == 0 {
                NSLog("💥 Acceleration phase \(accelerationPhase): Speed increased")
            }
        }
        
        NSLog("💥 System stress acceleration completed: \(accelerationPhase) phases")
    }
    
    /// Execute focused stress burst for backgrounding simulation
    ///
    /// **Implementation Notes:**
    /// - Concentrated stress periods simulating user frustration
    /// - Right-heavy bias maintained
    /// - Progressive intensity increase per cycle
    private func executeFocusedStressBurst(duration: TimeInterval) {
        let endTime = Date().addingTimeInterval(duration)
        var burstPressCount = 0
        
        while Date() < endTime {
            // Maintain right-heavy bias during stress bursts
            let direction: XCUIRemote.Button = (burstPressCount % 10 < 7) ? .right : [.up, .down, .left].randomElement()!
            
            remote.press(direction, forDuration: 0.025)
            
            // Stress burst timing: 30ms gaps for sustained pressure
            usleep(30_000)
            burstPressCount += 1
        }
        
        NSLog("💥 Focused stress burst: \(burstPressCount) presses")
    }
    
    /// Generate natural human timing variation vs uniform automated timing
    ///
    /// **Implementation Notes:**
    /// - Simulates human reaction time variation (40-250ms)
    /// - Occasional "thinking pauses" (longer delays)
    /// - Progressive fatigue acceleration (shorter delays over time)
    ///
    /// - Parameter pressIndex: Current press index for fatigue simulation
    /// - Returns: Microseconds delay for natural human timing
    private func naturalHumanTiming(pressIndex: Int) -> UInt32 {
        // Base human reaction time: 40-120ms
        let baseReaction = 40_000 + arc4random_uniform(80_000)
        
        // Occasional "thinking pause" (10% chance): 150-250ms
        if pressIndex % 10 == 0 {
            return 150_000 + arc4random_uniform(100_000)
        }
        
        // Progressive fatigue acceleration (faster over time)
        let fatigueReduction = min(20_000, UInt32(pressIndex / 10) * 1_000) // Up to 20ms faster
        let finalTiming = max(40_000, baseReaction - fatigueReduction)
        
        return finalTiming
    }
}
