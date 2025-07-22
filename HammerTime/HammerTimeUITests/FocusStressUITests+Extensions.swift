//
//  FocusStressUITests+Extensions.swift
//  HammerTimeUITests
//
//  V9.0 Progressive Stress System - Based on SuccessfulRepro6 Pattern

import XCTest
import os.log

// MARK: - V9.0 Progressive Stress System

extension FocusStressUITests {

    /// Retains allocated ballast data for the lifetime of the test run so the OS cannot reclaim it prematurely.
    static var memoryBallast: [Any] = []

    // MARK: - Stage 1: Baseline Establishment (0-30s)
    
    /// **Stage 1: Baseline establishment following SuccessfulRepro6 pattern**
    /// 
    /// **Purpose:**
    /// - Establish 52MB baseline memory usage
    /// - Begin natural-timed navigation following proven pattern
    /// - Create initial system state for progressive stress buildup
    ///
    /// **Timing**: Natural human intervals (200-800ms) from successful reproductions
    func executeStage1Baseline(duration: TimeInterval) {
        NSLog("STAGE-1: Baseline establishment (Target: 52MB memory)")
        
        // PROGRESSIVE MEMORY ALLOCATION
        // Each chunk = 1 MB, staged for system processing
        // 5 chunks = 5 MB total system stress
        // Target: 52 MB total memory usage
        
        NSLog("STAGE-1-MEMORY: 5 MB baseline allocation (Target: 52 MB total)")
        
        // 5 MB ballast for baseline memory pressure
        let ballastMB = 5
        for _ in 0..<ballastMB {
            // Each megabyte = 50,000 strings of ~20 chars = ~1MB
            let megabyteOfStrings = Array(0..<50000).map { index in
                "baseline_\(index)_\(UUID().uuidString.prefix(8))"
            }
            FocusStressUITests.memoryBallast.append(megabyteOfStrings)
            
            // Breathing space for memory allocation
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // STAGE 1: Natural baseline navigation
        let navigationCount = 10
        for i in 0..<navigationCount {
            let interval = Double.random(in: 0.4...0.8) // 400-800ms natural timing
            Thread.sleep(forTimeInterval: interval)
            
            // Right-heavy pattern (75% right, 25% down)
            if i % 4 == 3 {
                remote.press(.down)
            } else {
                remote.press(.right)
            }
            
            // Every 5th navigation: pause for backlog surfacing
            if (i + 1) % 5 == 0 {
                NSLog("STAGE-1: Backlog surfacing pause at \(i + 1)")
                Thread.sleep(forTimeInterval: 1.2)
            }
        }
        
        NSLog("STAGE-1: \(navigationCount) natural navigations completed")
        Thread.sleep(forTimeInterval: 2.0) // Stage completion pause
        
        NSLog("STAGE-1 COMPLETE: Baseline established with \(navigationCount) navigations")
        
        // End of Stage 1
    }
    
    // MARK: - Stage 2: Level 1 Stress (30-90s)
    
    /// **Stage 2: Level 1 stress targeting 61MB memory escalation**
    /// 
    /// **Progressive Escalation:**
    /// - Memory: 52MB → 61MB (+9MB ballast)
    /// - Timing: Slightly faster intervals (150-600ms)
    /// - Pattern: Maintain right-heavy bias with progressive system stress
    ///
    /// **Evidence**: SuccessfulRepro6 showed 61MB at this stage
    func executeStage2Level1Stress(duration: TimeInterval) {
        NSLog("STAGE-2: Level 1 stress (Target: 61MB memory)")
        
        // PROGRESSIVE MEMORY ALLOCATION
        // Additional 9 MB for 61MB total (52MB baseline + 9MB)
        // Designed to approach but not exceed memory pressure threshold
        
        NSLog("STAGE-2-MEMORY: +13 MB allocation (Target: 65 MB total)")
        
        // 13 MB additional ballast for Level 1 stress
        let additionalBallastMB = 13
        for _ in 0..<additionalBallastMB {
            let megabyteOfStrings = Array(0..<50000).map { index in
                "level1_\(index)_\(UUID().uuidString.prefix(8))"
            }
            FocusStressUITests.memoryBallast.append(megabyteOfStrings)
            
            // Breathing space for memory allocation
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // STAGE 2: Moderately accelerated navigation
        let stressCount = 20
        for i in 0..<stressCount {
            let interval = Double.random(in: 0.3...0.6) // 300-600ms slightly faster
            Thread.sleep(forTimeInterval: interval)
            
            // Right-heavy pattern with Up bursts every 8th
            if i % 8 == 7 {
                remote.press(.up)
            } else if i % 4 == 3 {
                remote.press(.down)
            } else {
                remote.press(.right)
            }
            
            // Every 10th navigation: pause for backlog surfacing
            if (i + 1) % 10 == 0 {
                NSLog("STAGE-2: Backlog surfacing pause at \(i + 1)")
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        
        NSLog("STAGE-2: \(stressCount) level 1 stress navigations")
        Thread.sleep(forTimeInterval: 2.0) // Stage completion pause
        
        NSLog("STAGE-2 COMPLETE: Level 1 stress with \(stressCount) navigations")
        
        // End of Stage 2
    }
    
    // MARK: - Stage 3: Level 2 Stress (90-180s)
    
    /// **Stage 3: Level 2 stress targeting 62MB memory with stall detection**
    /// 
    /// **Progressive Escalation:**
    /// - Memory: 61MB → 62MB (+1MB incremental)
    /// - Timing: Faster intervals (100-400ms)
    /// - Focus: Begin monitoring for 1000ms+ stalls (early warning)
    ///
    /// **Evidence**: SuccessfulRepro6 sustained 62MB during this phase
    func executeStage3Level2Stress(duration: TimeInterval) {
        NSLog("STAGE-3: Level 2 stress (Target: 62MB, monitor >1000ms stalls)")
        
        // PROGRESSIVE MEMORY ALLOCATION
        // Additional 1 MB for 62MB total approach to critical threshold
        // This should trigger initial >1000ms stalls
        
        NSLog("STAGE-3-MEMORY: +1 MB allocation (Target: 62 MB total)")
        
        // 1 MB additional ballast for Level 2 stress
        let additionalBallastMB = 1
        for _ in 0..<additionalBallastMB {
            let megabyteOfStrings = Array(0..<50000).map { index in
                "level2_\(index)_\(UUID().uuidString.prefix(8))"
            }
            FocusStressUITests.memoryBallast.append(megabyteOfStrings)
            
            // Breathing space for memory allocation
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // STAGE 3: Accelerated navigation approaching critical
        let level2Count = 15
        for i in 0..<level2Count {
            let interval = Double.random(in: 0.25...0.5) // 250-500ms faster
            Thread.sleep(forTimeInterval: interval)
            
            // Right-heavy pattern with mixed directions
            if i % 6 == 5 {
                remote.press(.up)
            } else if i % 4 == 3 {
                remote.press(.down)
            } else {
                remote.press(.right)
            }
            
            // Every 8th navigation: brief pause for stall detection
            if (i + 1) % 8 == 0 {
                NSLog("STAGE-3: Brief pause for stall detection at \(i + 1)")
                Thread.sleep(forTimeInterval: 0.8)
            }
        }
        
        NSLog("STAGE-3: \(level2Count) level 2 stress navigations")
        Thread.sleep(forTimeInterval: 2.0) // Stage completion pause
        
        NSLog("STAGE-3 COMPLETE: Level 2 stress with \(level2Count) navigations")
        NSLog("MONITOR: Check for >5179ms stalls and system failure indicators")
        
        // End of Stage 3
    }
    
    // MARK: - Stage 4: Critical Stress (180s+)
    
    /// **Stage 4: Critical stress targeting 79MB memory failure**
    /// 
    /// **Critical Escalation:**
    /// - Memory: 62MB → 79MB (+17MB critical ballast)
    /// - Timing: Variable (50-300ms) to create hardware/software desync
    /// - Target: >5179ms RunLoop stalls indicating InfinityBug breakthrough
    ///
    /// **Evidence**: SuccessfulRepro6 reached 79MB during final failure
    func executeStage4CriticalStress(duration: TimeInterval) {
        NSLog("STAGE-4: Critical stress (Target: 79MB, >5179ms stalls)")
        
        // PROGRESSIVE MEMORY ALLOCATION
        // Additional 17 MB for 79MB total critical threshold
        // This should trigger >5179ms stalls and system failure
        
        NSLog("STAGE-4-MEMORY: +17 MB critical allocation (Target: 79 MB total)")
        
        // 17 MB additional ballast for Critical stress
        let additionalBallastMB = 17
        for _ in 0..<additionalBallastMB {
            let megabyteOfStrings = Array(0..<50000).map { index in
                "critical_\(index)_\(UUID().uuidString.prefix(8))"
            }
            FocusStressUITests.memoryBallast.append(megabyteOfStrings)
            
            // Breathing space for memory allocation
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // STAGE 4: Critical navigation targeting system failure
        let criticalCount = 10
        for i in 0..<criticalCount {
            let interval = Double.random(in: 0.2...0.4) // 200-400ms approaching critical
            Thread.sleep(forTimeInterval: interval)
            
            // Right-heavy pattern with accelerated changes
            if i % 5 == 4 {
                remote.press(.up)
            } else if i % 3 == 2 {
                remote.press(.down)
            } else {
                remote.press(.right)
            }
            
            // Every 5th navigation: pause for >5179ms stall detection
            if (i + 1) % 5 == 0 {
                NSLog("STAGE-4: \(criticalCount) critical navigations")
                Thread.sleep(forTimeInterval: 0.6)
                
                NSLog("STAGE-4-CRITICAL: Pause for >5179ms stall detection at \(i + 1)")
                Thread.sleep(forTimeInterval: 1.5)
            }
        }
        
        NSLog("STAGE-4 COMPLETE: Critical stress with \(criticalCount) navigations")
        NSLog("MONITOR: Check for >5179ms stalls and system failure indicators")
        
        // End of Stage 4
    }
} 