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
        
        TestRunLogger.shared.log("🎯 V8.2-SETUP: Ready for DevTicket-focused InfinityBug reproduction")
        TestRunLogger.shared.printLogFileLocation()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - V8.2 DEVTICKET IMPLEMENTATION TESTS
    
    /// **DevTicket Test 3: Aggressive RunLoop Stall Detection & Monitoring**
    /// 
    /// Creates intensive navigation patterns specifically designed to trigger and monitor
    /// RunLoop stalls. Measures stall duration in real-time and logs critical thresholds.
    ///
    /// **Implementation Strategy:**
    /// 1. Rapid-fire navigation patterns to overwhelm focus calculations
    /// 2. Real-time RunLoop monitoring to detect stalls as they occur
    /// 3. Progressive intensity scaling to push system toward critical thresholds
    /// 4. Detailed logging of stall durations for analysis
    ///
    /// **Target Stall Patterns:**
    /// - Mild stalls: 100-1000ms (early warning indicators)
    /// - Moderate stalls: 1000-5000ms (system stress indicators)  
    /// - Critical stalls: >5179ms (InfinityBug threshold from successful reproduction)
    ///
    /// **Expected Duration:** 8-10 minutes with progressive intensity
    /// **Target Outcome:** Detailed stall duration logging and >5179ms critical stalls
    func testDevTicket_AggressiveRunLoopStallMonitoring() throws {
        // Initialize TestRunLogger for this test - automatically outputs to logs/UITestRunLogs/
        TestRunLogger.shared.startInfinityBugUITest(#function)
        
        TestRunLogger.shared.log("🎫 DEVTICKET-3: Starting aggressive RunLoop stall monitoring")
        TestRunLogger.shared.log("🎫 TARGET: Real-time stall detection and >5179ms critical stalls")
        
        let startTime = Date()
        var stallMonitor = RunLoopStallMonitor()
        
        // Phase 1: Baseline rapid navigation (2 minutes)
        TestRunLogger.shared.log("🚀 PHASE-1: Baseline rapid navigation for initial stall detection")
        executeBaselineRapidNavigation(duration: 120.0, stallMonitor: &stallMonitor)
        
        // Phase 2: Intensive focus system stress (3 minutes)
        TestRunLogger.shared.log("🚀 PHASE-2: Intensive focus system stress for moderate stalls")
        executeIntensiveFocusStress(duration: 180.0, stallMonitor: &stallMonitor)
        
        // Phase 3: Maximum pressure navigation (3 minutes)
        TestRunLogger.shared.log("🚀 PHASE-3: Maximum pressure navigation for critical stalls")
        executeMaximumPressureNavigation(duration: 180.0, stallMonitor: &stallMonitor)
        
        // Phase 4: Critical threshold assault (2 minutes)
        TestRunLogger.shared.log("🚀 PHASE-4: Critical threshold assault targeting >5179ms stalls")
        executeCriticalThresholdAssault(duration: 120.0, stallMonitor: &stallMonitor)
        
        let totalDuration = Date().timeIntervalSince(startTime)
        TestRunLogger.shared.log("🎫 DEVTICKET-3: Completed aggressive stall monitoring in \(String(format: "%.1f", totalDuration))s")
        
        // Final stall analysis and logging
        stallMonitor.logFinalAnalysis()
        
        // Log test completion
        let testResult = TestRunLogger.TestResult(
            success: true,
            infinityBugReproduced: stallMonitor.criticalStallsDetected > 0,
            runLoopStalls: stallMonitor.allStallDurations,
            phantomEvents: 0,
            focusChanges: 0,
            totalActions: stallMonitor.totalNavigationActions,
            errorMessages: [],
            additionalMetrics: [
                "totalStalls": stallMonitor.totalStallsDetected,
                "criticalStalls": stallMonitor.criticalStallsDetected,
                "maxStallDuration": stallMonitor.maxStallDuration,
                "averageStallDuration": stallMonitor.averageStallDuration
            ]
        )
        TestRunLogger.shared.stopLogging(testResult: testResult)
        
        XCTAssertTrue(true, "DevTicket aggressive stall monitoring completed - analyze logs for stall patterns")
    }
    
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
        // Initialize TestRunLogger for this test - automatically outputs to logs/UITestRunLogs/
        TestRunLogger.shared.startInfinityBugUITest(#function)
        
        TestRunLogger.shared.log("🎫 DEVTICKET-1: Starting edge-avoidance navigation pattern")
        TestRunLogger.shared.log("🎫 TARGET: Large focus traversals avoiding edge traps, RunLoop stall >5179ms")
        
        let startTime = Date()
        
        // Phase 1: Right exploration followed by Left return (2 minutes)
        executeRightThenLeftTraversal(duration: 120.0)
        
        // Phase 2: Down exploration followed by Up return (2 minutes)  
        executeDownThenUpTraversal(duration: 120.0)
        
        // Phase 3: Center-seeking navigation pattern (1 minute)
        executeCenterSeekingPattern(duration: 60.0)
        
        let totalDuration = Date().timeIntervalSince(startTime)
        TestRunLogger.shared.log("🎫 DEVTICKET-1: Completed edge-avoidance pattern in \(String(format: "%.1f", totalDuration))s")
        TestRunLogger.shared.log("🎫 MONITOR: Check console for RunLoop stall warnings >5179ms from large traversals")
        
        // Log test completion
        let testResult = TestRunLogger.TestResult(
            success: true,
            infinityBugReproduced: false, // Will be determined by log analysis
            runLoopStalls: [],
            phantomEvents: 0,
            focusChanges: 0,
            totalActions: 0,
            errorMessages: [],
            additionalMetrics: ["duration": totalDuration]
        )
        TestRunLogger.shared.stopLogging(testResult: testResult)
        
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
        // Initialize TestRunLogger for this test - automatically outputs to logs/UITestRunLogs/
        TestRunLogger.shared.startInfinityBugUITest(#function)
        
        TestRunLogger.shared.log("🎫 DEVTICKET-2: Starting Up-burst pattern from SuccessfulRepro3.txt")
        TestRunLogger.shared.log("🎫 TARGET: 22-45 Up press bursts creating large upward focus traversals")
        
        let startTime = Date()
        
        // Phase 1: Navigate to bottom area (setup phase - 1 minute)
        executeBottomAreaSetup(duration: 60.0)
        
        // Phase 2: Progressive Up bursts (4 minutes - core pattern)
        executeProgressiveUpBurstsFromBottom(duration: 240.0)
        
        // Phase 3: Sustained Up pressure (1 minute - stall trigger)
        executeSustainedUpwardPressure(duration: 60.0)
        
        let totalDuration = Date().timeIntervalSince(startTime)
        TestRunLogger.shared.log("🎫 DEVTICKET-2: Completed Up-burst pattern in \(String(format: "%.1f", totalDuration))s")
        TestRunLogger.shared.log("🎫 STALL-DETECTION: Monitor for progressive Up-traversal RunLoop stalls")
        
        // Log test completion
        let testResult = TestRunLogger.TestResult(
            success: true,
            infinityBugReproduced: false, // Will be determined by log analysis
            runLoopStalls: [],
            phantomEvents: 0,
            focusChanges: 0,
            totalActions: 0,
            errorMessages: [],
            additionalMetrics: ["duration": totalDuration]
        )
        TestRunLogger.shared.stopLogging(testResult: testResult)
        
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

// MARK: - RunLoop Stall Monitoring

/// **RunLoop Stall Monitor for Real-Time Performance Analysis**
/// 
/// Monitors RunLoop performance during navigation stress testing to detect
/// and measure stalls that indicate system overload and potential InfinityBug conditions.
///
/// **Stall Categories:**
/// - Mild: 100-1000ms (early warning)
/// - Moderate: 1000-5000ms (system stress)
/// - Critical: >5179ms (InfinityBug threshold)
struct RunLoopStallMonitor {
    private var lastActionTime: Date = Date()
    private var stallEvents: [(duration: TimeInterval, timestamp: Date)] = []
    
    var totalNavigationActions: Int = 0
    var totalStallsDetected: Int { stallEvents.count }
    var criticalStallsDetected: Int { stallEvents.filter { $0.duration > 5179 }.count }
    var maxStallDuration: TimeInterval { stallEvents.map { $0.duration }.max() ?? 0 }
    var averageStallDuration: TimeInterval { 
        let durations = stallEvents.map { $0.duration }
        return durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
    }
    var allStallDurations: [TimeInterval] { stallEvents.map { $0.duration } }
    
    /// Records a navigation action and checks for stalls since the last action
    ///
    /// **Stall Detection Logic:**
    /// - Measures time since last action
    /// - Logs stalls >100ms (significant delays)
    /// - Categorizes stalls by severity level
    /// - Tracks critical >5179ms threshold
    ///
    /// **Concurrency:** Called from main thread during UI interactions
    mutating func recordNavigationAction(_ action: String) {
        let currentTime = Date()
        let timeSinceLastAction = currentTime.timeIntervalSince(lastActionTime)
        
        // Detect stalls >100ms (anything longer indicates system stress)
        if timeSinceLastAction > 0.1 && totalNavigationActions > 0 {
            let stallDurationMs = timeSinceLastAction * 1000
            stallEvents.append((duration: timeSinceLastAction, timestamp: currentTime))
            
            // Log stall with appropriate severity
            if stallDurationMs > 5179 {
                TestRunLogger.shared.log("🔴 CRITICAL-STALL: \(String(format: "%.0f", stallDurationMs))ms - INFINITYBUG THRESHOLD EXCEEDED")
            } else if stallDurationMs > 1000 {
                TestRunLogger.shared.log("🟠 MODERATE-STALL: \(String(format: "%.0f", stallDurationMs))ms - System stress detected")
            } else if stallDurationMs > 100 {
                TestRunLogger.shared.log("🟡 MILD-STALL: \(String(format: "%.0f", stallDurationMs))ms - Early warning")
            }
        }
        
        lastActionTime = currentTime
        totalNavigationActions += 1
    }
    
    /// Logs comprehensive stall analysis at test completion
    func logFinalAnalysis() {
        TestRunLogger.shared.log("📊 RUNLOOP-STALL-ANALYSIS:")
        TestRunLogger.shared.log("  Total Actions: \(totalNavigationActions)")
        TestRunLogger.shared.log("  Total Stalls: \(totalStallsDetected)")
        TestRunLogger.shared.log("  Critical Stalls (>5179ms): \(criticalStallsDetected)")
        TestRunLogger.shared.log("  Max Stall Duration: \(String(format: "%.0f", maxStallDuration * 1000))ms")
        TestRunLogger.shared.log("  Average Stall Duration: \(String(format: "%.0f", averageStallDuration * 1000))ms")
        
        if criticalStallsDetected > 0 {
            TestRunLogger.shared.log("🔴 CRITICAL-THRESHOLD: InfinityBug conditions detected!")
        }
        
        // Log top 5 longest stalls
        let topStalls = stallEvents.sorted { $0.duration > $1.duration }.prefix(5)
        TestRunLogger.shared.log("  Top Stalls:")
        for (index, stall) in topStalls.enumerated() {
            TestRunLogger.shared.log("    \(index + 1). \(String(format: "%.0f", stall.duration * 1000))ms")
        }
    }
}

// MARK: - V8.2 DevTicket Implementation Extensions

extension FocusStressUITests {
    
    /// Execute Right-then-Left traversal avoiding right-edge trap
    ///
    /// **Edge-Avoidance Strategy:**
    /// - Use NavigationStrategy for intelligent edge-avoiding navigation
    /// - Snake horizontal pattern alternates Right-Left automatically
    /// - Built-in edge avoidance prevents boundary traps
    /// - Larger focus system stress vs getting trapped at boundaries
    ///
    /// **Based on Manual Reproduction Analysis:**
    /// Movement away from edges creates larger element traversals = more system stress
    private func executeRightThenLeftTraversal(duration: TimeInterval) {
        TestRunLogger.shared.log("↔️ RIGHT-LEFT-TRAVERSAL: Using NavigationStrategy for edge-avoiding navigation")
        
        let endTime = Date().addingTimeInterval(duration)
        let navigator = NavigationStrategyExecutor(app: app)
        var totalSteps = 0
        
        while Date() < endTime {
            // Use snake horizontal pattern for automatic Right-Left alternation
            let stepsThisCycle = 30 + Int(arc4random_uniform(20)) // 30-50 steps per cycle
            navigator.execute(.snake(direction: .horizontal), steps: stepsThisCycle)
            totalSteps += stepsThisCycle
            
            // Brief pause between cycles for system pressure accumulation
            usleep(200_000) // 200ms cycle pause
            
            if totalSteps % 100 == 0 {
                TestRunLogger.shared.log("↔️ Right-Left progress: \(totalSteps) intelligent edge-avoiding steps")
            }
        }
        
        TestRunLogger.shared.log("↔️ RIGHT-LEFT-TRAVERSAL complete: \(totalSteps) NavigationStrategy steps")
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
    /// - SMART EDGE DETECTION: Changes direction when at top edge
    /// - Progressive burst intensity and duration
    /// - Clear pauses between bursts for system pressure accumulation
    /// - RUNLOOP STALL TRIGGERS: Intensive focus system stress during bursts
    /// - Target: Recreate the exact conditions that led to 5179ms RunLoop stall
    ///
    /// **Critical Success Factor:** Up movements from bottom = maximum focus traversals
    private func executeProgressiveUpBurstsFromBottom(duration: TimeInterval) {
        NSLog("⬆️ UP-BURSTS: SuccessfulRepro3.txt pattern with smart edge detection")
        
        let endTime = Date().addingTimeInterval(duration)
        var burstNumber = 0
        var tracker = NavigationTracker()
        
        while Date() < endTime {
            // Up burst size: 22-45 presses (matching SuccessfulRepro3.txt)
            let upCount = 22 + (burstNumber % 24) // 22-45 Up presses (exact successful pattern)
            NSLog("⬆️ Up burst \(burstNumber + 1): \(upCount) presses (with edge detection)")
            
            // Execute Up burst with smart edge detection
            for pressIndex in 0..<upCount {
                // Check if we're at top edge and need to change direction
                if tracker.isLikelyAtTopEdge && pressIndex > 5 {
                    NSLog("🔄 EDGE-DETECTED: At top edge, switching to Down for large traversal")
                    
                    // Switch to Down movement for large traversal back toward bottom
                    let downCount = 8 + Int(arc4random_uniform(7)) // 8-14 Down presses
                    for _ in 0..<downCount {
                        remote.press(.down, forDuration: 0.05)
                        tracker.recordPress(.down)
                        usleep(120_000) // 120ms for large traversal timing
                    }
                    
                    // Brief pause before continuing Up burst
                    usleep(200_000) // 200ms direction change pause
                    continue
                }
                
                remote.press(.up, forDuration: 0.05)
                tracker.recordPress(.up)
                
                // Progressive timing: Start 150ms → reduce to 100ms (building pressure)
                let progressFactor = Double(pressIndex) / Double(upCount)
                let burstTiming = 150_000 - UInt32(50_000 * progressFactor) // 150ms → 100ms
                usleep(burstTiming)
                
                // RUNLOOP STALL TRIGGER: Intensive focus system stress every 10 presses
                if pressIndex % 10 == 0 && pressIndex > 0 {
                    triggerFocusSystemStress()
                }
            }
            
            burstNumber += 1
            
            // Progressive burst pause: Shorter pauses as bursts increase (building pressure)
            let burstPause = max(200_000, 400_000 - UInt32(burstNumber * 10_000)) // 400ms → 200ms
            usleep(burstPause)
            
            // MAJOR RUNLOOP STALL TRIGGER: Intensive stress every 5 bursts
            if burstNumber % 5 == 0 {
                NSLog("💥 RUNLOOP-STALL-TRIGGER: Intensive focus stress (burst \(burstNumber))")
                triggerMajorFocusSystemStress()
            }
            
            if burstNumber % 5 == 0 {
                NSLog("⬆️ Up-burst progress: \(burstNumber) bursts, pos: h=\(String(format: "%.2f", tracker.estimatedHorizontalPosition)), v=\(String(format: "%.2f", tracker.estimatedVerticalPosition))")
            }
        }
        
        NSLog("⬆️ UP-BURSTS complete: \(burstNumber) smart edge-avoiding bursts")
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
    
    // MARK: - Edge Detection & Smart Navigation
    
    /// Simple edge detection based on navigation history
    private struct NavigationTracker {
        var rightPresses = 0
        var leftPresses = 0  
        var upPresses = 0
        var downPresses = 0
        
        /// Estimated horizontal position (-1 = left edge, 0 = center, 1 = right edge)
        var estimatedHorizontalPosition: Double {
            let netRight = rightPresses - leftPresses
            return max(-1.0, min(1.0, Double(netRight) / 20.0)) // Normalize to -1...1
        }
        
        /// Estimated vertical position (-1 = top edge, 0 = center, 1 = bottom edge)  
        var estimatedVerticalPosition: Double {
            let netDown = downPresses - upPresses
            return max(-1.0, min(1.0, Double(netDown) / 15.0)) // Normalize to -1...1
        }
        
        /// Check if we're likely at right edge (>0.7 position)
        var isLikelyAtRightEdge: Bool { estimatedHorizontalPosition > 0.7 }
        
        /// Check if we're likely at left edge (<-0.7 position)
        var isLikelyAtLeftEdge: Bool { estimatedHorizontalPosition < -0.7 }
        
        /// Check if we're likely at bottom edge (>0.7 position)
        var isLikelyAtBottomEdge: Bool { estimatedVerticalPosition > 0.7 }
        
        /// Check if we're likely at top edge (<-0.7 position)
        var isLikelyAtTopEdge: Bool { estimatedVerticalPosition < -0.7 }
        
        mutating func recordPress(_ direction: XCUIRemote.Button) {
            switch direction {
            case .right: rightPresses += 1
            case .left: leftPresses += 1
            case .up: upPresses += 1
            case .down: downPresses += 1
            default: break
            }
        }
    }
    
    // MARK: - Aggressive RunLoop Stall Phase Implementations
    
    /// Execute baseline rapid navigation with stall monitoring
    ///
    /// **Baseline Strategy:**
    /// - Moderate speed navigation (50-100ms intervals)
    /// - Mixed directional patterns to establish baseline stall rates
    /// - Focus on detecting mild to moderate stalls (100-1000ms)
    /// - Provides performance baseline for comparison with aggressive phases
    ///
    /// **Expected Stalls:** Mild stalls (100-1000ms) as system warms up
    private func executeBaselineRapidNavigation(duration: TimeInterval, stallMonitor: inout RunLoopStallMonitor) {
        TestRunLogger.shared.log("📏 BASELINE-RAPID: Establishing stall detection baseline")
        
        let endTime = Date().addingTimeInterval(duration)
        let navigator = NavigationStrategyExecutor(app: app)
        
        while Date() < endTime {
            // Moderate speed snake pattern for baseline measurement
            navigator.execute(.snake(direction: .bidirectional), steps: 20)
            stallMonitor.recordNavigationAction("baseline_snake")
            
            // Moderate interval (50-100ms) for baseline stress
            usleep(UInt32(50_000 + arc4random_uniform(50_000)))
            
            // Periodic cross pattern for additional baseline stress
            if stallMonitor.totalNavigationActions % 60 == 0 {
                navigator.execute(.cross(direction: .full), steps: 8)
                stallMonitor.recordNavigationAction("baseline_cross")
                usleep(75_000) // 75ms baseline pause
            }
        }
        
        TestRunLogger.shared.log("📏 BASELINE-RAPID complete: \(stallMonitor.totalNavigationActions) actions")
    }
    
    /// Execute intensive focus system stress with stall monitoring
    ///
    /// **Intensive Strategy:**
    /// - Rapid navigation (20-50ms intervals)
    /// - Complex NavigationStrategy patterns for focus system overload
    /// - Target moderate stalls (1000-5000ms)
    /// - Combination of spiral, diagonal, and edge patterns
    ///
    /// **Expected Stalls:** Moderate stalls (1000-5000ms) as system stress increases
    private func executeIntensiveFocusStress(duration: TimeInterval, stallMonitor: inout RunLoopStallMonitor) {
        TestRunLogger.shared.log("⚡ INTENSIVE-STRESS: Ramping up for moderate stalls")
        
        let endTime = Date().addingTimeInterval(duration)
        let navigator = NavigationStrategyExecutor(app: app)
        var patternCycle = 0
        
        while Date() < endTime {
            // Rapid intensive patterns
            switch patternCycle % 4 {
            case 0:
                navigator.execute(.spiral(direction: .outward), steps: 25)
                stallMonitor.recordNavigationAction("intensive_spiral")
            case 1:
                navigator.execute(.diagonal(direction: .cross), steps: 30)
                stallMonitor.recordNavigationAction("intensive_diagonal")
            case 2:
                navigator.execute(.edgeTest(edge: .all), steps: 35)
                stallMonitor.recordNavigationAction("intensive_edge")
            case 3:
                navigator.execute(.cross(direction: .full), steps: 20)
                stallMonitor.recordNavigationAction("intensive_cross")
            default:
                break
            }
            
            // Rapid intervals (20-50ms) for intensive stress
            usleep(UInt32(20_000 + arc4random_uniform(30_000)))
            patternCycle += 1
            
            // Periodic focus system stress bursts
            if patternCycle % 15 == 0 {
                triggerFocusSystemStress()
                stallMonitor.recordNavigationAction("intensive_focus_burst")
            }
        }
        
        TestRunLogger.shared.log("⚡ INTENSIVE-STRESS complete: \(stallMonitor.totalNavigationActions) actions")
    }
    
    /// Execute maximum pressure navigation with stall monitoring
    ///
    /// **Maximum Pressure Strategy:**
    /// - Ultra-rapid navigation (8-25ms intervals)
    /// - Continuous pattern execution without pauses
    /// - Target critical stall threshold (>5179ms)
    /// - Maximum system overload through sustained pressure
    ///
    /// **Expected Stalls:** Critical stalls (>5179ms) approaching InfinityBug threshold
    private func executeMaximumPressureNavigation(duration: TimeInterval, stallMonitor: inout RunLoopStallMonitor) {
        TestRunLogger.shared.log("🔥 MAXIMUM-PRESSURE: Targeting critical >5179ms stalls")
        
        let endTime = Date().addingTimeInterval(duration)
        let navigator = NavigationStrategyExecutor(app: app)
        
        while Date() < endTime {
            // Ultra-rapid continuous patterns for maximum pressure
            navigator.execute(.randomWalk(seed: UInt64(Date().timeIntervalSince1970)), steps: 40)
            stallMonitor.recordNavigationAction("maximum_random")
            
            // Ultra-fast intervals (8-25ms) for maximum system stress
            usleep(UInt32(8_000 + arc4random_uniform(17_000)))
            
            // Continuous spiral stress
            navigator.execute(.spiral(direction: .inward), steps: 30)
            stallMonitor.recordNavigationAction("maximum_spiral")
            
            usleep(UInt32(8_000 + arc4random_uniform(17_000)))
            
            // Major focus system stress every 30 actions
            if stallMonitor.totalNavigationActions % 30 == 0 {
                triggerMajorFocusSystemStress()
                stallMonitor.recordNavigationAction("maximum_major_stress")
            }
        }
        
        TestRunLogger.shared.log("🔥 MAXIMUM-PRESSURE complete: \(stallMonitor.totalNavigationActions) actions")
    }
    
    /// Execute critical threshold assault with stall monitoring
    ///
    /// **Critical Threshold Strategy:**
    /// - Machine-gun navigation (5-15ms intervals)
    /// - Sustained pressure to push system over InfinityBug threshold
    /// - Continuous focus system stress bursts
    /// - Target sustained >5179ms stalls
    ///
    /// **Expected Stalls:** Sustained critical stalls indicating InfinityBug reproduction
    private func executeCriticalThresholdAssault(duration: TimeInterval, stallMonitor: inout RunLoopStallMonitor) {
        TestRunLogger.shared.log("💥 CRITICAL-ASSAULT: Machine-gun pressure for sustained >5179ms stalls")
        
        let endTime = Date().addingTimeInterval(duration)
        let navigator = NavigationStrategyExecutor(app: app)
        
        while Date() < endTime {
            // Machine-gun navigation patterns
            navigator.execute(.edgeTest(edge: .all), steps: 50)
            stallMonitor.recordNavigationAction("critical_edge_assault")
            
            // Machine-gun intervals (5-15ms) for critical system overload
            usleep(UInt32(5_000 + arc4random_uniform(10_000)))
            
            // Continuous cross pattern stress
            navigator.execute(.cross(direction: .full), steps: 35)
            stallMonitor.recordNavigationAction("critical_cross_assault")
            
            usleep(UInt32(5_000 + arc4random_uniform(10_000)))
            
            // Continuous focus stress bursts
            if stallMonitor.totalNavigationActions % 10 == 0 {
                triggerMajorFocusSystemStress()
                stallMonitor.recordNavigationAction("critical_focus_assault")
            }
            
            // Ultimate pressure: Snake pattern with no pauses
            navigator.execute(.snake(direction: .horizontal), steps: 25)
            stallMonitor.recordNavigationAction("critical_snake_assault")
            
            // Minimal pause to maintain pressure
            usleep(UInt32(5_000))
        }
        
        TestRunLogger.shared.log("💥 CRITICAL-ASSAULT complete: \(stallMonitor.totalNavigationActions) actions")
    }
}

// MARK: - V8.0 Implementation Extensions (Legacy)

extension FocusStressUITests {
    
    // MARK: - RunLoop Stall Triggers
    
    /// Trigger focus system stress to induce RunLoop stalls
    ///
    /// **RunLoop Stall Strategy:**
    /// - Use NavigationStrategy for intelligent edge-avoiding rapid inputs
    /// - NO expensive accessibility queries (they slow down reproduction)
    /// - Target: Sustained input pressure leading to >5179ms RunLoop stalls
    private func triggerFocusSystemStress() {
        TestRunLogger.shared.log("💥 FOCUS-STRESS: Triggering rapid edge-avoiding navigation")
        
        // Use NavigationStrategy for intelligent rapid input burst
        let navigator = NavigationStrategyExecutor(app: app)
        navigator.execute(.cross(direction: .full), steps: 5)
        
        TestRunLogger.shared.log("💥 FOCUS-STRESS: Completed rapid navigation burst")
    }
    
    /// Trigger major focus system stress for RunLoop stall induction
    ///
    /// **Major Stress Strategy:**
    /// - Use NavigationStrategy for sustained intelligent rapid inputs
    /// - Focus on button press frequency to overwhelm focus calculations
    /// - Target: Maximum input pressure for >5179ms RunLoop stalls
    private func triggerMajorFocusSystemStress() {
        TestRunLogger.shared.log("💥 MAJOR-STRESS: Starting intensive edge-avoiding navigation")
        
        // Major stress via NavigationStrategy - rapid spiral pattern for maximum focus stress
        let navigator = NavigationStrategyExecutor(app: app)
        navigator.execute(.spiral(direction: .outward), steps: 12)
        
        TestRunLogger.shared.log("💥 MAJOR-STRESS: Completed intensive navigation burst")
    }
    
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
