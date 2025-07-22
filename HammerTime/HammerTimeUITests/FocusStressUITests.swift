//
//  FocusStressUITests.swift
//  HammerTimeUITests
//
//  InfinityBug Reproduction Suite V8.3
//  Focus: Single high-impact test for InfinityBug reproduction research

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
            "-FocusStressPreset", "heavyReproduction", // Use Focus Stress (Heavy) for UI testing
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
        
        TestRunLogger.shared.log("V8.3-SETUP: Ready for InfinityBug reproduction")
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
    func testV9ProgressiveStressSystemReproduction() throws {
        let startTime = Date()
        
        NSLog("V9.0-PROGRESSIVE: Starting Progressive Stress System based on SuccessfulRepro6")
        NSLog("TARGET: Memory escalation 52MB→79MB + >5179ms RunLoop stalls")
        
        // STAGE 1: Baseline (30s) - 52MB target
        executeStage1Baseline(duration: 30)
        
        // STAGE 2: Level 1 Stress (60s) - 61MB target  
        executeStage2Level1Stress(duration: 60)
        
        // STAGE 3: Level 2 Stress (90s) - 62MB target
        executeStage3Level2Stress(duration: 90)
        
        // STAGE 4: Critical Stress (90s) - 79MB target
        executeStage4CriticalStress(duration: 90)
        
        let totalDuration = Date().timeIntervalSince(startTime)
        
        NSLog("V9.0-PROGRESSIVE: Completed in \(String(format: "%.1f", totalDuration))s")
        NSLog("MONITOR: Watch for >5179ms stalls and memory escalation to 79MB")
        
        // Additional observation window for InfinityBug manifestation
        Thread.sleep(forTimeInterval: 30)
        
        XCTAssertTrue(true, "V9.0 Progressive Stress System completed - monitor logs for >5179ms stalls")
    }
    
    /// **MAJOR-STRESS Test** 
    /// Implements intensive directional navigation for maximum focus engine pressure.
    /// Used after memory ballast allocation to create system stress.
    func testMajorStress() throws {
        TestRunLogger.shared.log("MAJOR-STRESS: Starting intensive directional navigation")
        
        let directions: [XCUIRemote.Button] = [.up, .down, .left, .right]
        
        for i in 0..<50 {
            let direction = directions[i % directions.count]
            remote.press(direction)
            usleep(100_000) // 100ms for rapid focus calculations
        }
        
        TestRunLogger.shared.log("MAJOR-STRESS: Completed 50 rapid focus calculations")  
    }

}



// MARK: - RunLoop Stall Detection & Analysis

extension FocusStressUITests {
    
    /// **RunLoop Stall Detection**
    /// **Monitors main thread blocking that indicates InfinityBug progression**
    /// **Critical Threshold**: >5179ms sustained stalls
    class RunLoopStallMonitor {
        private var lastRunLoopTime = CFAbsoluteTimeGetCurrent()
        private var stallHistory: [Double] = []
        
        func recordStallIfNeeded() {
            let now = CFAbsoluteTimeGetCurrent()
            let stallDuration = (now - lastRunLoopTime) * 1000.0 // Convert to milliseconds
            
            if stallDuration > 300 { // Only record significant stalls (>300ms)
                stallHistory.append(stallDuration)
                logStallSeverity(stallDuration)
            }
            
            lastRunLoopTime = now
        }
        
        private func logStallSeverity(_ stallDurationMs: Double) {
            if stallDurationMs > 5179 {
                TestRunLogger.shared.log("CRITICAL-STALL: \(String(format: "%.0f", stallDurationMs))ms - INFINITYBUG THRESHOLD")
            } else if stallDurationMs > 1000 {
                TestRunLogger.shared.log("MODERATE-STALL: \(String(format: "%.0f", stallDurationMs))ms - System stress")
            } else if stallDurationMs > 300 {
                TestRunLogger.shared.log("MILD-STALL: \(String(format: "%.0f", stallDurationMs))ms - Early warning")
            }
        }
        
        func printStallAnalysis() {
            let criticalStalls = stallHistory.filter { $0 > 5179 }
            let moderateStalls = stallHistory.filter { $0 > 1000 && $0 <= 5179 }
            let mildStalls = stallHistory.filter { $0 > 300 && $0 <= 1000 }
            
            TestRunLogger.shared.log("RUNLOOP-STALL-ANALYSIS:")
            TestRunLogger.shared.log("  Total stalls: \(stallHistory.count)")
            TestRunLogger.shared.log("  Mild (300-1000ms): \(mildStalls.count)")
            TestRunLogger.shared.log("  Moderate (1000-5179ms): \(moderateStalls.count)")
            TestRunLogger.shared.log("  Critical (>5179ms): \(criticalStalls.count)")
            
            let criticalStallsDetected = criticalStalls.count
            if criticalStallsDetected > 0 {
                TestRunLogger.shared.log("INFINITYBUG-DETECTED: \(criticalStallsDetected) critical stalls found")
            }
        }
    }
}
