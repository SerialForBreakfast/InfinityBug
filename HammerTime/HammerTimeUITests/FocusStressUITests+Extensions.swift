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
    static var memoryBallast: [Data] = []

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
        NSLog("📊 STAGE-1: Baseline establishment (Target: 52MB memory)")
        
        let endTime = Date().addingTimeInterval(duration)
        var navigationCount = 0
        
        // Start with 5 MB memory allocation for baseline and retain
        let baselineBallast = Data(count: 5 * 1024 * 1024)
        FocusStressUITests.memoryBallast.append(baselineBallast)
        NSLog("💾 STAGE-1-MEMORY: 5 MB baseline allocation (Target: 52 MB total)")
        
        while Date() < endTime {
            // Faster human-like timing (80-200 ms) extracted from manual logs
            let naturalDelay = UInt32.random(in: 80_000...200_000)

            // Snake pattern R→D→L→U maximises focus traversals
            let sequence = [XCUIRemote.Button.right,
                            .down,
                            .left,
                            .up]
            let nextDirection = sequence[navigationCount % sequence.count]
            self.pressAndRecord(nextDirection)
            
            navigationCount += 1

            // Micro-idle every 20 presses keeps XCTest stable
            if navigationCount % 20 == 0 { usleep(1_000) }
            // 0.9 s pause every 100 presses lets backlog surface (mirrors manual run)
            if navigationCount % 100 == 0 {
                usleep(900_000)
                NSLog("📊 STAGE-1: Backlog surfacing pause at \(navigationCount)")
            }
            
            usleep(naturalDelay)
            
            if navigationCount % 10 == 0 {
                NSLog("📊 STAGE-1: \(navigationCount) natural navigations completed")
            }
        }
        
        NSLog("📊 STAGE-1 COMPLETE: Baseline established with \(navigationCount) navigations")
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
        NSLog("⚡ STAGE-2: Level 1 stress (Target: 61MB memory)")
        
        let endTime = Date().addingTimeInterval(duration)
        var stressCount = 0
        
        // Larger early ballast (13 MB) – manual failures plateau at ~65 MB
        let level1Ballast = Data(count: 13 * 1024 * 1024) // +13 MB
        FocusStressUITests.memoryBallast.append(level1Ballast)
        NSLog("💾 STAGE-2-MEMORY: +13 MB allocation (Target: 65 MB total)")
        
        while Date() < endTime {
            // Faster timing (40-120 ms) increases queue pressure
            let level1Delay = UInt32.random(in: 40_000...120_000)

            // Directional entropy – 60 % Right, 20 % Down, 20 % Up
            let direction: XCUIRemote.Button
            if stressCount % 5 == 0 {
                direction = .down
            } else if stressCount % 8 == 0 {
                direction = .up
            } else {
                direction = .right
            }

            self.pressAndRecord(direction)
            stressCount += 1

            // Stability + backlog surfacing
            if stressCount % 20 == 0 { usleep(1_000) }
            if stressCount % 100 == 0 {
                usleep(900_000)
                NSLog("⚡ STAGE-2: Backlog surfacing pause at \(stressCount)")
            }

            usleep(level1Delay)
            
            if stressCount % 15 == 0 {
                NSLog("⚡ STAGE-2: \(stressCount) level 1 stress navigations")
            }
        }
        
        NSLog("⚡ STAGE-2 COMPLETE: Level 1 stress with \(stressCount) navigations")
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
        NSLog("🔥 STAGE-3: Level 2 stress (Target: 62MB, monitor >1000ms stalls)")
        
        let endTime = Date().addingTimeInterval(duration)
        var level2Count = 0
        
        // Incremental memory pressure (+1MB for 62MB total)
        let level2Ballast = Data(count: 1 * 1024 * 1024) // +1 MB
        FocusStressUITests.memoryBallast.append(level2Ballast)
        NSLog("💾 STAGE-3-MEMORY: +1 MB allocation (Target: 62 MB total)")
        
        while Date() < endTime {
            // Much faster timing (10-60 ms) to replicate manual bursts
            let level2Delay = UInt32.random(in: 10_000...60_000)
            
            // Intensified navigation pattern
            let direction: XCUIRemote.Button
            if level2Count % 12 == 0 {
                direction = .up // Up bursts for focus stress
            } else if level2Count % 6 == 0 {
                direction = .down // Down sequences
            } else {
                direction = .right // Continue right-heavy pattern
            }
            
            self.pressAndRecord(direction)
            level2Count += 1
            
            // Stability + backlog surfacing
            if level2Count % 20 == 0 { usleep(1_000) }
            if level2Count % 100 == 0 {
                usleep(500_000)
                NSLog("🔥 STAGE-3: Brief pause for stall detection at \(level2Count)")
            }

            usleep(level2Delay)
            
            if level2Count % 20 == 0 {
                NSLog("🔥 STAGE-3: \(level2Count) level 2 stress navigations")
            }
        }
        
        NSLog("🔥 STAGE-3 COMPLETE: Level 2 stress with \(level2Count) navigations")
        NSLog("🔥 MONITOR: Check for >5179ms stalls and system failure indicators")
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
        NSLog("💥 STAGE-4: Critical stress (Target: 79MB, >5179ms stalls)")
        
        let endTime = Date().addingTimeInterval(duration)
        var criticalCount = 0
        
        // Critical memory allocation to reach 79MB failure threshold
        let criticalBallast = Data(count: 17 * 1024 * 1024) // +17 MB for 79 MB total
        FocusStressUITests.memoryBallast.append(criticalBallast)
        NSLog("💾 STAGE-4-MEMORY: +17 MB critical allocation (Target: 79 MB total)")
        
        while Date() < endTime {
            // Extreme rapid mashing (0-40 ms) – true critical pressure
            let criticalDelay = UInt32.random(in: 0...40_000)
            
            // Aggressive navigation pattern for critical failure
            let direction: XCUIRemote.Button
            if criticalCount % 10 == 0 {
                direction = .up // Up sequences for polling fallback
            } else if criticalCount % 7 == 0 {
                direction = .down // Down for traversal stress
            } else {
                direction = .right // Right dominance
            }
            
            self.pressAndRecord(direction)
            criticalCount += 1
            
            // Stability + backlog surfacing
            if criticalCount % 25 == 0 {
                NSLog("💥 STAGE-4: \(criticalCount) critical navigations")
            }
            
            // Every 100 presses, add pause for critical stall detection
            if criticalCount % 100 == 0 {
                usleep(1_000_000) // 1 second pause for >5179ms stall detection
                NSLog("💥 STAGE-4-CRITICAL: Pause for >5179ms stall detection at \(criticalCount)")
            }

            usleep(criticalDelay)
        }
        
        NSLog("💥 STAGE-4 COMPLETE: Critical stress with \(criticalCount) navigations")
        NSLog("💥 MONITOR: Check for >5179ms stalls and system failure indicators")
    }
} 