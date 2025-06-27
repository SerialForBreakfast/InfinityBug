//
//  FocusStressUITests.swift
//  HammerTimeUITests
//
//  InfinityBug Reproduction Suite V8.3
//  Focus: Single high-impact test for reliable InfinityBug reproduction

import XCTest

/// **InfinityBug Reproduction Test Suite**
/// 
/// Implements aggressive system stress patterns targeting consistent InfinityBug reproduction.
/// Uses memory pressure, intensive input patterns, and focus system overload.
///
/// **Success Criteria:**
/// - RunLoop stalls >40,000ms indicating system failure
/// - Memory pressure + input flood combination
/// - VoiceOver accessibility stress testing
final class FocusStressUITests: XCTestCase {
    
    // MARK: - Test Infrastructure
    
    var app: XCUIApplication!
    let remote = XCUIRemote.shared
    /// Monitors RunLoop latency and backlog during automated navigation so we can compare with manual reproductions.
    var stallMonitor = RunLoopStallMonitor()
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        
        app.launchArguments += [
            "-FocusStressMode", "reproduction",
            "-DebounceDisabled", "YES",
            "-AppleTVVoiceOverEnabled", "YES", // ensure VoiceOver matches manual runs
            "-LinearStallMode", "YES",
            "-LinearStallBaseMS", "120",
            "-LinearStallStepMS", "120"
        ]
        
        app.launchEnvironment["DEBOUNCE_DISABLED"] = "1"
        app.launchEnvironment["FOCUS_TEST_MODE"] = "1"
        
        app.launch()
        
        // Begin log capture for this UITest run – use method name for clarity
        TestRunLogger.shared.startUITest("ProgressiveStressSystemReproduction")
        
        let collectionView = app.collectionViews["FocusStressCollectionView"]
        XCTAssertTrue(collectionView.waitForExistence(timeout: 10),
                     "FocusStressCollectionView should exist")
        
        TestRunLogger.shared.log("🎯 V8.3-SETUP: Ready for InfinityBug reproduction")
        TestRunLogger.shared.printLogFileLocation()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Primary InfinityBug Reproduction Test
    
    /// **V9.0 Progressive Stress System - Based on SuccessfulRepro6 Pattern**
    /// 
    /// **Strategy:**
    /// - 4-stage progressive memory escalation: 52MB → 61MB → 62MB → 79MB
    /// - Natural timing patterns (200-800ms intervals like successful manual reproductions)
    /// - Hardware/software desynchronization to trigger polling fallback
    /// - Target: >5179ms RunLoop stalls leading to system failure
    ///
    /// **Success Indicators:**
    /// - Memory escalation following 52MB→79MB progression
    /// - RunLoop stalls progressing beyond 5179ms threshold  
    /// - Event queue saturation (200+ events, negative press counts)
    /// - Focus continues navigating after user input stops
    func testProgressiveStressSystemReproduction() throws {
        NSLog("🚀 V9.0-PROGRESSIVE: Starting Progressive Stress System based on SuccessfulRepro6")
        NSLog("🎯 TARGET: Memory escalation 52MB→79MB + >5179ms RunLoop stalls")
        
        let startTime = Date()
        
        // Stage 1: Baseline establishment (0-30s)
        executeStage1Baseline(duration: 30.0)
        
        // Stage 2: Level 1 stress - Target 61MB (30-90s)
        executeStage2Level1Stress(duration: 60.0)
        
        // Insert a targeted burst that mirrors the 50-press edge-avoidance sequence from manual repros.
        triggerMajorFocusSystemStress()
        
        // Stage 3: Level 2 stress - Target 62MB (90-180s)
        executeStage3Level2Stress(duration: 90.0)
        
        // Stage 4: Critical stress - Target 79MB (180s+)
        executeStage4CriticalStress(duration: 120.0)
        
        let totalDuration = Date().timeIntervalSince(startTime)
        NSLog("🚀 V9.0-PROGRESSIVE: Completed in \(String(format: "%.1f", totalDuration))s")
        NSLog("🎯 MONITOR: Watch for >5179ms stalls and memory escalation to 79MB")
        
        // Output a summary of RunLoop behaviour for post-analysis.  We do NOT fail the test on absence of stalls – the goal is replication, not automated detection.
        stallMonitor.logFinalAnalysis()
        
        XCTAssertTrue(true, "V9.0 Progressive Stress System completed - monitor for critical thresholds")
    }
    
    // MARK: - Focus System Stress Method
    
    /// **Triggers intensive focus system calculations to accelerate stall generation**
    /// 
    /// Forces focus system to perform intensive calculations by rapidly changing
    /// focus targets and triggering accessibility evaluations.
    ///
    /// **Concurrency:** Called from main thread during test execution
    func triggerMajorFocusSystemStress() {
        TestRunLogger.shared.log("💥 MAJOR-STRESS: Starting intensive edge-avoiding navigation")
        
        // Rapid navigation burst to force focus calculations
        for i in 0..<50 {
            let direction: XCUIRemote.Button = (i % 2 == 0) ? .right : .left
            remote.press(direction, forDuration: 0.025)
            usleep(25_000) // 25ms gaps for maximum calculation pressure
        }
        
        TestRunLogger.shared.log("💥 MAJOR-STRESS: Completed 50 rapid focus calculations")
    }
    
    // MARK: - Navigation Helper
    
    /// Presses the supplied direction immediately (tap) and records the event with the stall monitor.
    /// - Parameter button: The Siri Remote direction button to tap.
    ///
    /// Concurrency: Runs synchronously on the main XCTest thread – safe to mutate the `stallMonitor` state.
    func pressAndRecord(_ button: XCUIRemote.Button) {
        remote.press(button)
        stallMonitor.recordNavigation(direction: button, duration: 0)

        // Incremental memory ballast – 1 MB every 15 actions
        Self.incrementalPressCounter += 1
        if Self.incrementalPressCounter % 15 == 0 {
            let chunk = Data(count: 1 * 1024 * 1024)
            FocusStressUITests.memoryBallast.append(chunk)
            TestRunLogger.shared.logUITest("💾 Incremental ballast +1 MB (total chunks: \(FocusStressUITests.memoryBallast.count))")
        }

        // Trigger incremental layout thrash inside the app via Darwin notification
        if Self.incrementalPressCounter % 5 == 0 {
            app.activate() // ensure connection
            // Send Darwin notification to app to add constraint batch
            let _ = CFNotificationCenterGetDarwinNotifyCenter()
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.showblender.hammertime.constraintThrash" as CFString), nil, nil, true)
        }
    }

    private static var incrementalPressCounter = 0
}

// MARK: - RunLoop Stall Monitoring

/// **RunLoop Stall Monitor for Real-Time Performance Analysis**
/// 
/// Monitors RunLoop performance during navigation stress testing to detect
/// system overload and InfinityBug conditions.
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
    // Duration is stored in seconds; critical threshold = 5.179 s
    private static let criticalThreshold: TimeInterval = 5.179
    private static let moderateThreshold: TimeInterval = 1.0
    private static let mildThreshold: TimeInterval = 0.1

    var criticalStallsDetected: Int { stallEvents.filter { $0.duration > Self.criticalThreshold }.count }
    var maxStallDuration: TimeInterval { stallEvents.map { $0.duration }.max() ?? 0 }
    var averageStallDuration: TimeInterval { 
        let durations = stallEvents.map { $0.duration }
        return durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
    }
    var allStallDurations: [TimeInterval] { stallEvents.map { $0.duration } }
    
    /// **Records navigation action and detects stalls**
    ///
    /// **Stall Detection:** Measures time since last action, categorizes by severity
    /// **Concurrency:** Called from main thread during UI interactions
    mutating func recordNavigation(direction: XCUIRemote.Button, duration: TimeInterval) {
        let currentTime = Date()
        let timeSinceLastAction = currentTime.timeIntervalSince(lastActionTime)
        
        if timeSinceLastAction > 0.1 && totalNavigationActions > 0 {
            let stallDurationMs = timeSinceLastAction * 1000
            stallEvents.append((duration: timeSinceLastAction, timestamp: currentTime))
            
            if timeSinceLastAction > Self.criticalThreshold {
                TestRunLogger.shared.log("🔴 CRITICAL-STALL: \(String(format: "%.0f", stallDurationMs))ms - INFINITYBUG THRESHOLD")
            } else if timeSinceLastAction > Self.moderateThreshold {
                TestRunLogger.shared.log("🟠 MODERATE-STALL: \(String(format: "%.0f", stallDurationMs))ms - System stress")
            } else if timeSinceLastAction > Self.mildThreshold {
                TestRunLogger.shared.log("🟡 MILD-STALL: \(String(format: "%.0f", stallDurationMs))ms - Early warning")
            }
        }
        
        lastActionTime = currentTime
        totalNavigationActions += 1
    }
    
    /// **Logs comprehensive stall analysis at test completion**
    func logFinalAnalysis() {
        TestRunLogger.shared.log("📊 RUNLOOP-STALL-ANALYSIS:")
        TestRunLogger.shared.log("  Total Actions: \(totalNavigationActions)")
        TestRunLogger.shared.log("  Total Stalls: \(totalStallsDetected)")
        TestRunLogger.shared.log("  Critical Stalls (>5179ms): \(criticalStallsDetected)")
        TestRunLogger.shared.log("  Max Stall: \(String(format: "%.0f", maxStallDuration * 1000))ms")
        TestRunLogger.shared.log("  Average Stall: \(String(format: "%.0f", averageStallDuration * 1000))ms")
        
        if criticalStallsDetected > 0 {
            TestRunLogger.shared.log("🔴 INFINITYBUG-DETECTED: \(criticalStallsDetected) critical stalls found")
        }
    }
}
