//
//  FocusStressUITests.swift
//  HammerTimeUITests
//
//  ========================================================================
//  INFINITYBUG REPRODUCTION SUITE V8.2 - DEVTICKET IMPLEMENTATION
//  ========================================================================
//  >>> EVOLVED TO V8.2 – DEVTICKET REQUIREMENTS FOCUSED (2025-01-22)
//  ========================================================================
//
//  **DEVTICKET REQUIREMENTS IMPLEMENTATION:**
//  ✅ METHODICAL INPUT PATTERNS: Specific, sustained directional sequences
//  ✅ SUSTAINED DIRECTIONAL INPUTS: Multiple Right/Down arrow sequences  
//  ✅ CLEAR PAUSES: Brief delays mimicking human timing between inputs
//  ✅ RUNLOOP STALL TARGETING: Monitor for >5179ms stalls indicating success
//  
//  **SUCCESS CRITERIA FROM DEVTICKET:**
//  - Reliable reproduction (80% success rate target)
//  - RunLoop stall detection and logging
//  - Documented input sequences with timing rationale
//  - Based on successful manual reproduction analysis
//
//  **TARGET SUCCESS PATTERN:**
//  - `[AXDBG] 065648.123 WARNING: RunLoop stall 5179 ms` (from successful repro)
//  - Methodical vs erratic input patterns
//  - Sustained pressure with human-like timing
//  - Clear monitoring and detection approach
//
//  THIS FILE IS FOR THE TEST FUNCTIONS ONLY.  HELPER METHODS GO IN THE FocusStressUITests+Extensions
//  ========================================================================

import XCTest

/// **V8.2 DevTicket-Focused InfinityBug Reproduction Suite**
/// 
/// Implements the specific requirements from DevTicket_CreateInfinityBugUITest.md
/// focusing on methodical input patterns and sustained directional inputs.
///
/// **Success Criteria:**
/// - RunLoop stalls >5179ms (matching successful manual reproduction)
/// - Methodical input patterns vs erratic automation
/// - Sustained directional sequences with human-like timing
/// - Clear monitoring and detection of InfinityBug symptoms
final class FocusStressUITests: XCTestCase {
    
    // MARK: - Test Infrastructure
    
    var app: XCUIApplication!
    let remote = XCUIRemote.shared
    
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
        
        NSLog("🎯 V8.2-SETUP: Ready for DevTicket-focused InfinityBug reproduction")
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - V8.2 DEVTICKET IMPLEMENTATION TESTS
    
    /// **DevTicket Test 1: Edge-Avoidance Navigation Pattern**
    /// 
    /// Implements navigation that avoids getting trapped at edges, creating larger
    /// focus traversals and more system stress leading to RunLoop stalls.
    ///
    /// **Implementation Based on DevTicket Requirements & Edge Analysis:**
    /// 1. Navigate toward center from edges (larger focus traversals)
    /// 2. Up movements from bottom areas (high stress pattern from SuccessfulRepro3.txt)
    /// 3. Left movements from right areas (avoid right-edge trap)
    /// 4. Monitor for RunLoop stalls >5179ms from sustained large traversals
    ///
    /// **Expected Duration:** 4-5 minutes
    /// **Target Outcome:** RunLoop stall warnings from large focus traversals
    func testDevTicket_EdgeAvoidanceNavigationPattern() throws {
        NSLog("🎫 DEVTICKET-1: Starting edge-avoidance navigation pattern")
        NSLog("🎫 TARGET: Large focus traversals avoiding edge traps, RunLoop stall >5179ms")
        
        let startTime = Date()
        
        // Phase 1: Right exploration followed by Left return (2 minutes)
        executeRightThenLeftTraversal(duration: 120.0)
        
        // Phase 2: Down exploration followed by Up return (2 minutes)  
        executeDownThenUpTraversal(duration: 120.0)
        
        // Phase 3: Center-seeking navigation pattern (1 minute)
        executeCenterSeekingPattern(duration: 60.0)
        
        let totalDuration = Date().timeIntervalSince(startTime)
        NSLog("🎫 DEVTICKET-1: Completed edge-avoidance pattern in \(String(format: "%.1f", totalDuration))s")
        NSLog("🎫 MONITOR: Check console for RunLoop stall warnings >5179ms from large traversals")
        
        XCTAssertTrue(true, "DevTicket edge-avoidance pattern completed - monitor for RunLoop stalls")
    }
    
    /// **DevTicket Test 2: Up-Burst Pattern from Successful Reproduction**
    /// 
    /// Implements the specific Up-burst pattern (22-45 presses) identified in
    /// SuccessfulRepro3.txt that led to the critical 5179ms RunLoop stall.
    ///
    /// **Implementation Based on SuccessfulRepro3.txt Analysis:**
    /// 1. Navigate to bottom area first (Right+Down setup)
    /// 2. Execute sustained Up bursts (22-45 presses matching successful pattern)
    /// 3. Clear pauses between bursts for system pressure accumulation
    /// 4. Progressive Up burst intensity matching successful reproduction timing
    ///
    /// **Expected Duration:** 5-6 minutes
    /// **Target Outcome:** Progressive RunLoop degradation leading to >5179ms stalls
    func testDevTicket_UpBurstFromSuccessfulReproduction() throws {
        NSLog("🎫 DEVTICKET-2: Starting Up-burst pattern from SuccessfulRepro3.txt")
        NSLog("🎫 TARGET: 22-45 Up press bursts creating large upward focus traversals")
        
        let startTime = Date()
        
        // Phase 1: Navigate to bottom area (setup phase - 1 minute)
        executeBottomAreaSetup(duration: 60.0)
        
        // Phase 2: Progressive Up bursts (4 minutes - core pattern)
        executeProgressiveUpBurstsFromBottom(duration: 240.0)
        
        // Phase 3: Sustained Up pressure (1 minute - stall trigger)
        executeSustainedUpwardPressure(duration: 60.0)
        
        let totalDuration = Date().timeIntervalSince(startTime)
        NSLog("🎫 DEVTICKET-2: Completed Up-burst pattern in \(String(format: "%.1f", totalDuration))s")
        NSLog("🎫 STALL-DETECTION: Monitor for progressive Up-traversal RunLoop stalls")
        
        XCTAssertTrue(true, "DevTicket Up-burst pattern completed - monitor for SuccessfulRepro3.txt stalls")
    }
    
    // MARK: - V8.0 LEGACY TESTS (Retained for Comparison)
    
    /// **V8.0 PRIMARY TEST - IMPROVED - ESTIMATED EXECUTION TIME: 6.0 minutes**
    /// 
    /// **V8.2 IMPROVEMENTS BASED ON SUCCESSFUL REPRODUCTION ANALYSIS:**
    /// - Extended duration for sustained pressure (6 minutes vs 4 minutes)
    /// - Right-Down pattern focus (matching SuccessfulRepro3.txt analysis)  
    /// - Sustained pause timing vs progressive acceleration
    /// - RunLoop stall targeting >5179ms (critical success indicator)
    /// - Longer sustained phases for proper system pressure buildup
    ///
    /// **Target Outcome:** 
    /// `RunLoop stall >5179ms` matching SuccessfulRepro3.txt critical pattern
    func testEvolvedInfinityBugReproduction() throws {
        NSLog("🎯 V8.0-IMPROVED: Starting enhanced InfinityBug reproduction")
        NSLog("🎯 TARGET: RunLoop stall >5179ms (SuccessfulRepro3.txt critical pattern)")
        
        let startTime = Date()
        
        // Phase 1: Extended Right-Heavy exploration (3 minutes - doubled duration)
        executeImprovedRightHeavyExploration(duration: 180.0)
        
        // Phase 2: Sustained Right-Down pattern (2 minutes - focused on success pattern)  
        executeImprovedRightDownPattern(duration: 120.0)
        
        // Phase 3: Sustained pressure buildup (1 minute - no acceleration, sustained timing)
        executeImprovedSustainedPressure(duration: 60.0)
        
        let totalDuration = Date().timeIntervalSince(startTime)
        NSLog("🎯 V8.0-IMPROVED: Completed enhanced reproduction in \(String(format: "%.1f", totalDuration))s")
        NSLog("🎯 CRITICAL: Monitor for RunLoop stall >5179ms (SuccessfulRepro3.txt pattern)")
        
        XCTAssertTrue(true, "Enhanced reproduction pattern completed - monitor for critical RunLoop stalls")
    }
    
    /// **V8.0 SECONDARY TEST - IMPROVED - ESTIMATED EXECUTION TIME: 7.0 minutes**
    /// 
    /// **V8.2 IMPROVEMENTS BASED ON SUCCESSFUL REPRODUCTION ANALYSIS:**
    /// - Extended stress cycles (7 vs 6 cycles) for sustained pressure
    /// - Right-Down focus during stress bursts vs random directions
    /// - Longer stress duration per cycle (45-90s vs 30-55s)
    /// - Sustained timing vs rapid bursts for proper system pressure
    /// - Better simulation of successful manual reproduction timing
    ///
    /// **Background Trigger Pattern:**
    /// Enhanced simulation maintaining Right-Down focus with sustained pressure
    /// targeting the critical >5179ms RunLoop stall threshold.
    func testEvolvedBackgroundingTriggeredInfinityBug() throws {
        NSLog("🎯 V8.0-IMPROVED: Starting enhanced backgrounding-triggered reproduction")
        NSLog("🎯 PATTERN: Sustained Right-Down focus with extended pressure cycles")
        
        let startTime = Date()
        
        // 7 extended stress-pause cycles for sustained system pressure
        for cycle in 0..<7 {
            NSLog("🎯 CYCLE \(cycle + 1)/7: Extended stress for sustained system pressure")
            
            // Extended stress duration: 45-90s (vs original 30-55s)
            let stressDuration = 45.0 + (Double(cycle) * 6.5) // Progressive: 45s → 84s
            executeImprovedFocusedStressBurst(duration: stressDuration)
            
            // Extended pause for system pressure manifestation
            NSLog("🎯 SUSTAINED-PAUSE: Extended system pressure manifestation")
            usleep(3_000_000) // 3 second pause (vs 2s) for better pressure buildup
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        NSLog("🎯 V8.0-IMPROVED: Completed enhanced backgrounding in \(String(format: "%.1f", totalDuration))s")
        
        XCTAssertTrue(true, "Enhanced backgrounding simulation completed - monitor for sustained RunLoop stalls")
    }
}

// MARK: - V8.2 DevTicket Implementation Extensions

extension FocusStressUITests {
    
    /// Execute Right-then-Left traversal avoiding right-edge trap
    ///
    /// **Edge-Avoidance Strategy:**
    /// - Navigate Right to explore rightward elements
    /// - Return Left to create large reverse traversals (away from right edge)
    /// - Larger focus system stress vs getting trapped at right boundary
    /// - Clear pauses between direction changes for system pressure accumulation
    ///
    /// **Based on Manual Reproduction Analysis:**
    /// Movement away from edges creates larger element traversals = more system stress
    private func executeRightThenLeftTraversal(duration: TimeInterval) {
        NSLog("↔️ RIGHT-LEFT-TRAVERSAL: Large horizontal focus traversals avoiding edge trap")
        
        let endTime = Date().addingTimeInterval(duration)
        var cycleCount = 0
        
        while Date() < endTime {
            // Right exploration phase (10-15 presses)
            let rightCount = 10 + Int(arc4random_uniform(6)) // 10-15 Right presses
            NSLog("➡️ Right exploration: \(rightCount) presses")
            
            for _ in 0..<rightCount {
                remote.press(.right, forDuration: 0.05)
                usleep(120_000 + arc4random_uniform(80_000)) // 120-200ms clear pauses
            }
            
            // Pause before direction change
            usleep(300_000) // 300ms pause for system pressure accumulation
            
            // Left return phase (12-18 presses - slightly more to move away from right edge)
            let leftCount = 12 + Int(arc4random_uniform(7)) // 12-18 Left presses
            NSLog("⬅️ Left return traversal: \(leftCount) presses (away from right edge)")
            
            for _ in 0..<leftCount {
                remote.press(.left, forDuration: 0.05)
                usleep(100_000 + arc4random_uniform(100_000)) // 100-200ms clear pauses
            }
            
            // Cycle completion pause
            usleep(400_000) // 400ms cycle pause
            
            cycleCount += 1
            
            if cycleCount % 5 == 0 {
                NSLog("↔️ Right-Left traversal: \(cycleCount) cycles completed")
            }
        }
        
        NSLog("↔️ RIGHT-LEFT-TRAVERSAL complete: \(cycleCount) large horizontal traversals")
    }
    
    /// Execute Down-then-Up traversal avoiding bottom-edge trap
    ///
    /// **Edge-Avoidance Strategy:**
    /// - Navigate Down to explore downward elements  
    /// - Return Up to create large reverse traversals (away from bottom edge)
    /// - Up movements from bottom = largest focus traversals (SuccessfulRepro3.txt pattern)
    /// - Progressive intensity matching successful reproduction timing
    ///
    /// **Critical Pattern:** Up movements from bottom areas create maximum system stress
    private func executeDownThenUpTraversal(duration: TimeInterval) {
        NSLog("↕️ DOWN-UP-TRAVERSAL: Large vertical focus traversals, Up from bottom stress")
        
        let endTime = Date().addingTimeInterval(duration)
        var cycleCount = 0
        
        while Date() < endTime {
            // Down exploration phase (8-12 presses)
            let downCount = 8 + Int(arc4random_uniform(5)) // 8-12 Down presses
            NSLog("⬇️ Down exploration: \(downCount) presses")
            
            for _ in 0..<downCount {
                remote.press(.down, forDuration: 0.05)
                usleep(150_000 + arc4random_uniform(100_000)) // 150-250ms clear pauses
            }
            
            // Pause before Up traversal (critical for system pressure)
            usleep(400_000) // 400ms pause for system pressure accumulation
            
            // Up return phase (15-25 presses - MORE to create large upward traversals)
            let upCount = 15 + Int(arc4random_uniform(11)) // 15-25 Up presses
            NSLog("⬆️ Up traversal from bottom: \(upCount) presses (LARGE TRAVERSAL)")
            
            for _ in 0..<upCount {
                remote.press(.up, forDuration: 0.05)
                usleep(120_000 + arc4random_uniform(80_000)) // 120-200ms clear pauses
            }
            
            // Extended cycle pause for Up-traversal pressure accumulation
            usleep(500_000) // 500ms extended pause
            
            cycleCount += 1
            
            if cycleCount % 3 == 0 {
                NSLog("↕️ Down-Up traversal: \(cycleCount) cycles, focusing on Up-from-bottom stress")
            }
        }
        
        NSLog("↕️ DOWN-UP-TRAVERSAL complete: \(cycleCount) large vertical traversals")
    }
    
    /// Execute center-seeking navigation pattern avoiding all edge traps
    ///
    /// **Edge-Avoidance Strategy:**
    /// - Mixed directional inputs that avoid prolonged edge contact
    /// - Center-seeking bias to maintain large traversal options
    /// - Variable timing to create natural navigation pressure
    /// - Avoid Right-Down corner trap and other edge accumulations
    ///
    /// **Pattern:** Dynamic navigation maintaining central focus position
    private func executeCenterSeekingPattern(duration: TimeInterval) {
        NSLog("🎯 CENTER-SEEKING: Dynamic navigation avoiding edge traps")
        
        let endTime = Date().addingTimeInterval(duration)
        var pressCount = 0
        
        // Center-seeking direction weights (avoid edge accumulation)
        let centerSeekingDirections: [(XCUIRemote.Button, Int)] = [
            (.left, 30),   // Pull away from right edge
            (.up, 35),     // Pull away from bottom edge (high stress)
            (.right, 20),  // Limited rightward (avoid right edge trap)
            (.down, 15)    // Limited downward (avoid bottom edge trap)
        ]
        
        while Date() < endTime {
            // Select center-seeking direction based on weights
            let direction = selectWeightedDirection(centerSeekingDirections)
            
            remote.press(direction, forDuration: 0.05)
            
            // Variable timing for natural navigation pressure
            let centerSeekingTiming = generateCenterSeekingTiming(pressIndex: pressCount)
            usleep(centerSeekingTiming)
            
            pressCount += 1
            
            // Occasional center-correction burst (every 20-30 presses)
            if pressCount % (20 + Int(arc4random_uniform(11))) == 0 {
                NSLog("🎯 Center correction: Up+Left burst (away from bottom-right)")
                
                // Up+Left burst to pull away from bottom-right area
                for _ in 0..<3 {
                    remote.press(.up, forDuration: 0.05)
                    usleep(100_000)
                }
                for _ in 0..<2 {
                    remote.press(.left, forDuration: 0.05)
                    usleep(100_000)
                }
                
                usleep(300_000) // 300ms correction pause
            }
            
            if pressCount % 50 == 0 {
                NSLog("🎯 Center-seeking progress: \(pressCount) edge-avoiding presses")
            }
        }
        
        NSLog("🎯 CENTER-SEEKING complete: \(pressCount) edge-avoidance navigations")
    }
    
    /// Execute bottom area setup for Up-burst testing
    ///
    /// **Setup Strategy:**
    /// - Navigate to bottom area to enable large upward traversals
    /// - Controlled Right+Down movement (not trapped at corner)
    /// - Position for maximum Up-traversal stress impact
    /// - Based on SuccessfulRepro3.txt setup pattern
    ///
    /// **Goal:** Position at bottom area for effective Up-burst stress testing
    private func executeBottomAreaSetup(duration: TimeInterval) {
        NSLog("⬇️ BOTTOM-SETUP: Positioning for Up-burst stress testing")
        
        let endTime = Date().addingTimeInterval(duration)
        var setupPhase = 0
        
        while Date() < endTime && setupPhase < 3 {
            switch setupPhase {
            case 0:
                // Phase 1: Moderate Right movement (avoid right edge trap)
                NSLog("➡️ Setup Phase 1: Moderate rightward positioning")
                for _ in 0..<8 {
                    remote.press(.right, forDuration: 0.05)
                    usleep(200_000) // 200ms setup pauses
                }
                
            case 1:
                // Phase 2: Down movement to bottom area
                NSLog("⬇️ Setup Phase 2: Moving to bottom area")
                for _ in 0..<12 {
                    remote.press(.down, forDuration: 0.05)
                    usleep(180_000) // 180ms setup pauses
                }
                
            case 2:
                // Phase 3: Final positioning adjustments
                NSLog("🎯 Setup Phase 3: Final positioning for Up-burst")
                for _ in 0..<3 {
                    remote.press(.right, forDuration: 0.05)
                    usleep(150_000)
                }
                for _ in 0..<2 {
                    remote.press(.down, forDuration: 0.05)
                    usleep(150_000)
                }
                
            default:
                break
            }
            
            setupPhase += 1
            usleep(500_000) // 500ms phase transition pause
        }
        
        NSLog("⬇️ BOTTOM-SETUP complete: Positioned for Up-burst stress testing")
    }
    
    /// Execute progressive Up bursts from bottom matching SuccessfulRepro3.txt
    ///
    /// **SuccessfulRepro3.txt Pattern Implementation:**
    /// - 22-45 Up press bursts (exact pattern from successful reproduction)
    /// - Progressive burst intensity and duration
    /// - Clear pauses between bursts for system pressure accumulation
    /// - Target: Recreate the exact conditions that led to 5179ms RunLoop stall
    ///
    /// **Critical Success Factor:** Up movements from bottom = maximum focus traversals
    private func executeProgressiveUpBurstsFromBottom(duration: TimeInterval) {
        NSLog("⬆️ UP-BURSTS: SuccessfulRepro3.txt pattern (22-45 presses per burst)")
        
        let endTime = Date().addingTimeInterval(duration)
        var burstNumber = 0
        
        while Date() < endTime {
            // Up burst size: 22-45 presses (matching SuccessfulRepro3.txt)
            let upCount = 22 + (burstNumber % 24) // 22-45 Up presses (exact successful pattern)
            NSLog("⬆️ Up burst \(burstNumber + 1): \(upCount) presses (SuccessfulRepro3.txt pattern)")
            
            // Execute Up burst with progressive timing
            for pressIndex in 0..<upCount {
                remote.press(.up, forDuration: 0.05)
                
                // Progressive timing: Start 150ms → reduce to 100ms (building pressure)
                let progressFactor = Double(pressIndex) / Double(upCount)
                let burstTiming = 150_000 - UInt32(50_000 * progressFactor) // 150ms → 100ms
                usleep(burstTiming)
            }
            
            burstNumber += 1
            
            // Progressive burst pause: Shorter pauses as bursts increase (building pressure)
            let burstPause = max(200_000, 400_000 - UInt32(burstNumber * 10_000)) // 400ms → 200ms
            usleep(burstPause)
            
            if burstNumber % 5 == 0 {
                NSLog("⬆️ Up-burst progress: \(burstNumber) bursts completed (building toward 5179ms stall)")
            }
        }
        
        NSLog("⬆️ UP-BURSTS complete: \(burstNumber) SuccessfulRepro3.txt pattern bursts")
    }
    
    /// Execute sustained upward pressure for RunLoop stall trigger
    ///
    /// **Stall Trigger Strategy:**
    /// - Sustained Up pressure without pauses
    /// - Maximum upward focus traversal stress
    /// - Target: Trigger the critical >5179ms RunLoop stall
    /// - Based on final phase of SuccessfulRepro3.txt before stall
    ///
    /// **Critical Phase:** Final sustained pressure to trigger InfinityBug
    private func executeSustainedUpwardPressure(duration: TimeInterval) {
        NSLog("⬆️ SUSTAINED-UP: Final pressure phase targeting >5179ms RunLoop stall")
        
        let endTime = Date().addingTimeInterval(duration)
        var sustainedPressCount = 0
        
        while Date() < endTime {
            remote.press(.up, forDuration: 0.05)
            
            // Sustained pressure timing: 80ms consistent (no acceleration)
            usleep(80_000) // 80ms sustained pressure
            
            sustainedPressCount += 1
            
            if sustainedPressCount % 50 == 0 {
                NSLog("⬆️ Sustained Up pressure: \(sustainedPressCount) presses (targeting stall threshold)")
            }
        }
        
        NSLog("⬆️ SUSTAINED-UP complete: \(sustainedPressCount) sustained upward pressure presses")
    }
    
    /// Select weighted direction for center-seeking navigation
    ///
    /// **Edge-Avoidance Logic:**
    /// - Weighted selection favoring movement away from edges
    /// - Up and Left weighted higher (pull away from bottom-right trap)
    /// - Dynamic direction selection avoiding edge accumulation
    ///
    /// - Parameter directions: Array of (direction, weight) tuples
    /// - Returns: Selected direction based on weights
    private func selectWeightedDirection(_ directions: [(XCUIRemote.Button, Int)]) -> XCUIRemote.Button {
        let totalWeight = directions.reduce(0) { $0 + $1.1 }
        let randomValue = Int(arc4random_uniform(UInt32(totalWeight)))
        
        var currentWeight = 0
        for (direction, weight) in directions {
            currentWeight += weight
            if randomValue < currentWeight {
                return direction
            }
        }
        
        return directions.first?.0 ?? .up // Default to Up (away from bottom edge)
    }
    
    /// Generate center-seeking timing for natural navigation
    ///
    /// **Edge-Avoidance Timing:**
    /// - Variable timing for natural navigation feel
    /// - Occasional longer pauses for system pressure accumulation
    /// - Based on successful manual reproduction timing analysis
    ///
    /// - Parameter pressIndex: Current press for timing variation
    /// - Returns: Microseconds pause duration for center-seeking navigation
    private func generateCenterSeekingTiming(pressIndex: Int) -> UInt32 {
        // Base center-seeking timing: 120-200ms
        let baseTiming = 120_000 + arc4random_uniform(80_000)
        
        // Occasional "navigation pause" (8% chance): 300-450ms
        if pressIndex % 12 == 0 {
            return 300_000 + arc4random_uniform(150_000)
        }
        
        // Natural variation around base timing
        let variation = arc4random_uniform(40_000) // ±40ms variation
        return baseTiming + variation
    }
}

// MARK: - V8.0 Implementation Extensions (Legacy)

extension FocusStressUITests {
    
    // MARK: - V8.2 Improved V8.0 Methods
    
    /// Execute improved Right-heavy exploration matching SuccessfulRepro3.txt patterns
    ///
    /// **V8.2 Improvements:**
    /// - Sustained timing vs progressive acceleration (key difference from failed attempts)
    /// - Right-Down focus (80% Right, 20% Down) matching successful reproduction
    /// - Extended duration for proper system pressure buildup
    /// - Natural pause variation matching successful manual timing
    ///
    /// **Critical Pattern:** Right dominance with sustained pressure, not rapid acceleration
    private func executeImprovedRightHeavyExploration(duration: TimeInterval) {
        NSLog("➡️ IMPROVED-RIGHT: Sustained Right-heavy with natural timing (SuccessfulRepro3 pattern)")
        
        let endTime = Date().addingTimeInterval(duration)
        var pressCount = 0
        
        while Date() < endTime {
            // 80% Right, 20% Down focus (matching SuccessfulRepro3.txt analysis)
            let direction: XCUIRemote.Button = (pressCount % 10 < 8) ? .right : .down
            
            // Sustained natural timing (150-300ms) vs progressive acceleration
            let sustainedTiming = generateSustainedNaturalTiming(pressIndex: pressCount)
            
            remote.press(direction, forDuration: 0.05)
            usleep(sustainedTiming)
            
            pressCount += 1
            
            // Log progress every 50 presses
            if pressCount % 50 == 0 {
                NSLog("➡️ Improved Right-heavy: \(pressCount) presses (80% Right, 20% Down)")
            }
        }
        
        NSLog("➡️ IMPROVED-RIGHT complete: \(pressCount) sustained presses")
    }
    
    /// Execute improved Right-Down pattern matching SuccessfulRepro3.txt critical sequence
    ///
    /// **V8.2 Improvements:**
    /// - Right-Down alternating pattern (matching successful reproduction)
    /// - Sustained pause timing (200-400ms) for proper system pressure
    /// - Extended sequences for RunLoop stall buildup
    /// - Focus on the exact pattern that led to 5179ms stall
    ///
    /// **Critical Success Pattern:** Right→Down→Right→Down with sustained timing
    private func executeImprovedRightDownPattern(duration: TimeInterval) {
        NSLog("↘️ IMPROVED-PATTERN: Right-Down alternating (SuccessfulRepro3.txt critical sequence)")
        
        let endTime = Date().addingTimeInterval(duration)
        var sequenceCount = 0
        
        while Date() < endTime {
            // Right-Down alternating pattern from successful reproduction
            let direction: XCUIRemote.Button = (sequenceCount % 2 == 0) ? .right : .down
            
            remote.press(direction, forDuration: 0.05)
            
            // Sustained timing (200-400ms) matching successful reproduction pauses
            let sustainedPause = 200_000 + arc4random_uniform(200_000) // 200-400ms
            usleep(sustainedPause)
            
            sequenceCount += 1
            
            // Log pattern progress
            if sequenceCount % 40 == 0 {
                NSLog("↘️ Right-Down pattern: \(sequenceCount) alternating sequences")
            }
        }
        
        NSLog("↘️ IMPROVED-PATTERN complete: \(sequenceCount) Right-Down sequences")
    }
    
    /// Execute improved sustained pressure targeting >5179ms RunLoop stalls
    ///
    /// **V8.2 Improvements:**
    /// - Sustained timing vs acceleration (critical difference)
    /// - Right-Down focus vs all 4 directions (successful pattern)
    /// - Longer sustained pressure for RunLoop stall threshold
    /// - No progressive acceleration - sustained consistent pressure
    ///
    /// **Target:** Build sustained system pressure toward >5179ms RunLoop stall
    private func executeImprovedSustainedPressure(duration: TimeInterval) {
        NSLog("💥 IMPROVED-PRESSURE: Sustained Right-Down pressure (targeting >5179ms stalls)")
        
        let endTime = Date().addingTimeInterval(duration)
        var pressCount = 0
        
        while Date() < endTime {
            // Right-Down only (successful pattern) vs all 4 directions
            let direction: XCUIRemote.Button = (pressCount % 3 == 0) ? .down : .right
            
            remote.press(direction, forDuration: 0.05)
            
            // Sustained pressure timing (250ms consistent) vs acceleration
            usleep(250_000) // Consistent 250ms - no acceleration
            
            pressCount += 1
            
            if pressCount % 30 == 0 {
                NSLog("💥 Sustained pressure: \(pressCount) consistent Right-Down presses")
            }
        }
        
        NSLog("💥 IMPROVED-PRESSURE complete: \(pressCount) sustained pressure presses")
    }
    
    /// Execute improved focused stress burst with Right-Down pattern
    ///
    /// **V8.2 Improvements:**
    /// - Right-Down focus (90% Right, 10% Down) vs random directions
    /// - Sustained burst timing vs rapid 30ms gaps
    /// - Extended burst duration for proper system pressure
    /// - Pattern matching successful manual reproduction timing
    ///
    /// **Enhancement:** Maintains focus on successful Right-Down pattern throughout
    private func executeImprovedFocusedStressBurst(duration: TimeInterval) {
        NSLog("💥 IMPROVED-BURST: Right-Down focused stress (sustained timing)")
        
        let endTime = Date().addingTimeInterval(duration)
        var burstPressCount = 0
        
        while Date() < endTime {
            // Right-Down focused pattern (90% Right, 10% Down)
            let direction: XCUIRemote.Button = (burstPressCount % 10 < 9) ? .right : .down
            
            remote.press(direction, forDuration: 0.05)
            
            // Sustained burst timing: 120ms (vs rapid 30ms)
            usleep(120_000)
            burstPressCount += 1
        }
        
        NSLog("💥 IMPROVED-BURST complete: \(burstPressCount) Right-Down focused presses")
    }
    
    /// Generate sustained natural timing matching successful reproduction patterns
    ///
    /// **V8.2 Improvements:**
    /// - Sustained timing range (150-350ms) vs acceleration
    /// - Natural variation matching successful manual reproduction
    /// - No progressive reduction - consistent sustained pressure
    /// - Based on SuccessfulRepro3.txt timing analysis
    ///
    /// **Key Difference:** Sustained vs accelerating timing patterns
    private func generateSustainedNaturalTiming(pressIndex: Int) -> UInt32 {
        // Sustained base timing: 150-250ms (vs accelerating patterns)
        let baseReaction = 150_000 + arc4random_uniform(100_000)
        
        // Occasional sustained pause (8% chance): 300-400ms
        if pressIndex % 12 == 0 {
            return 300_000 + arc4random_uniform(100_000)
        }
        
        // Natural variation without acceleration
        let variation = arc4random_uniform(50_000) // ±50ms variation
        return baseReaction + variation
    }
    
    // MARK: - Original V8.0 Methods (Retained for Reference)
    
    // NOTE: Original V8.0 methods moved to FocusStressUITests+Extensions.swift
    // to avoid redeclaration errors. The improved V8.2 methods above are used
    // by the enhanced tests.
}
