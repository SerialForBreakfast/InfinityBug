//
//  FocusStressUITests+Extensions.swift
//  HammerTimeUITests

import XCTest
import os.log

extension FocusStressUITests {
    
    /// **Strategy 1: Rapid Burst Navigation**
    ///
    /// Overwhelms focus system with rapid input bursts using 0-5ms gaps.
    /// Designed to create immediate system pressure and potential RunLoop stalls.
    ///
    /// **Implementation:**
    /// - 20-50 button presses per burst
    /// - 0-5ms gaps between presses (vs 30ms in V8.0)
    /// - Random direction changes every 5-10 presses
    /// - Brief recovery periods to allow stall accumulation
    func executeRapidBurstNavigation(duration: TimeInterval) {
        NSLog("💥 STRATEGY-1: Rapid Burst Navigation (0-5ms gaps)")
        
        let endTime = Date().addingTimeInterval(duration)
        var burstCount = 0
        
        while Date() < endTime {
            let burstSize = 20 + Int(arc4random_uniform(31)) // 20-50 presses per burst
            let direction = [XCUIRemote.Button.right, .left, .up, .down].randomElement()!
            
            NSLog("💥 Burst \(burstCount + 1): \(burstSize) \(direction) presses (0-5ms gaps)")
            
            for _ in 0..<burstSize {
                remote.press(direction, forDuration: 0.01)
                
                // Ultra-rapid gaps: 0-5ms (vs 30ms in V8.0)
                let microGap = arc4random_uniform(5_000) // 0-5ms
                if microGap > 0 {
                    usleep(microGap)
                }
            }
            
            burstCount += 1
            
            // Brief recovery to allow stall accumulation
            usleep(100_000) // 100ms recovery
        }
        
        NSLog("💥 STRATEGY-1 Complete: \(burstCount) rapid bursts executed")
    }
    
    /// **Strategy 2: Spiral Chaos Navigation**
    ///
    /// Creates unpredictable spiral patterns designed to confuse focus system
    /// and create navigation conflicts leading to RunLoop stalls.
    ///
    /// **Implementation:**
    /// - Clockwise/counterclockwise spiral patterns
    /// - Variable spiral sizes (3x3 to 7x7 grids)
    /// - Direction reversals mid-spiral
    /// - Overlapping spiral intersections
    func executeSpiralChaosNavigation(duration: TimeInterval) {
        NSLog("🌀 STRATEGY-2: Spiral Chaos Navigation (unpredictable patterns)")
        
        let endTime = Date().addingTimeInterval(duration)
        var spiralCount = 0
        
        while Date() < endTime {
            let spiralSize = 3 + Int(arc4random_uniform(5)) // 3-7 grid size
            let isClockwise = arc4random_uniform(2) == 0
            
            NSLog("🌀 Spiral \(spiralCount + 1): \(spiralSize)x\(spiralSize) grid, \(isClockwise ? "clockwise" : "counterclockwise")")
            
            executeSpiralPattern(size: spiralSize, clockwise: isClockwise)
            
            spiralCount += 1
            
            // Random direction reversal (30% chance)
            if arc4random_uniform(10) < 3 {
                NSLog("🌀 REVERSAL: Chaos direction change")
                let randomDir = [XCUIRemote.Button.right, .left, .up, .down].randomElement()!
                for _ in 0..<5 {
                    remote.press(randomDir, forDuration: 0.01)
                    usleep(10_000) // 10ms chaos gaps
                }
            }
        }
        
        NSLog("🌀 STRATEGY-2 Complete: \(spiralCount) spiral patterns executed")
    }
    
    /// **Strategy 3: Micro-Stutter Navigation**
    ///
    /// Rapid-fire inputs with 1ms gaps followed by brief recovery periods.
    /// Simulates system struggling to keep up with input processing.
    ///
    /// **Implementation:**
    /// - 1ms gaps between inputs (extreme rapid-fire)
    /// - 100-200 press sequences
    /// - Random direction changes every 10-20 presses
    /// - 50ms recovery periods
    func executeMicroStutterNavigation(duration: TimeInterval) {
        NSLog("⚡ STRATEGY-3: Micro-Stutter Navigation (1ms gaps)")
        
        let endTime = Date().addingTimeInterval(duration)
        var stutterCount = 0
        
        while Date() < endTime {
            let sequenceLength = 100 + Int(arc4random_uniform(101)) // 100-200 presses
            var direction = [XCUIRemote.Button.right, .left, .up, .down].randomElement()!
            
            NSLog("⚡ Stutter \(stutterCount + 1): \(sequenceLength) presses (1ms gaps)")
            
            for pressIndex in 0..<sequenceLength {
                remote.press(direction, forDuration: 0.005)
                usleep(1_000) // 1ms micro-gaps
                
                // Change direction every 10-20 presses
                if pressIndex % (10 + Int(arc4random_uniform(11))) == 0 {
                    direction = [XCUIRemote.Button.right, .left, .up, .down].randomElement()!
                }
            }
            
            stutterCount += 1
            
            // Brief recovery
            usleep(50_000) // 50ms recovery
        }
        
        NSLog("⚡ STRATEGY-3 Complete: \(stutterCount) stutter sequences executed")
    }
    
    /// **Strategy 4: Focus Thrashing Navigation**
    ///
    /// Rapid direction reversals designed to thrash the focus system
    /// by constantly changing navigation targets.
    ///
    /// **Implementation:**
    /// - Opposing direction pairs (Right→Left, Up→Down)
    /// - 2-5ms gaps between reversals
    /// - 50-100 reversal pairs per thrash session
    /// - Multiple simultaneous direction conflicts
    func executeFocusThrashingNavigation(duration: TimeInterval) {
        NSLog("🔄 STRATEGY-4: Focus Thrashing Navigation (direction reversals)")
        
        let endTime = Date().addingTimeInterval(duration)
        var thrashCount = 0
        
        let opposingPairs: [(XCUIRemote.Button, XCUIRemote.Button)] = [
            (.right, .left),
            (.up, .down),
            (.left, .right),
            (.down, .up)
        ]
        
        while Date() < endTime {
            let reversalCount = 50 + Int(arc4random_uniform(51)) // 50-100 reversals
            let (dir1, dir2) = opposingPairs.randomElement()!
            
            NSLog("🔄 Thrash \(thrashCount + 1): \(reversalCount) \(dir1)↔\(dir2) reversals")
            
            for _ in 0..<reversalCount {
                remote.press(dir1, forDuration: 0.005)
                usleep(UInt32(2_000 + arc4random_uniform(4_000))) // 2-5ms gaps
                
                remote.press(dir2, forDuration: 0.005)
                usleep(UInt32(2_000 + arc4random_uniform(4_000))) // 2-5ms gaps
            }
            
            thrashCount += 1
            
            // Micro recovery
            usleep(25_000) // 25ms recovery
        }
        
        NSLog("🔄 STRATEGY-4 Complete: \(thrashCount) thrashing sessions executed")
    }
    
    /// **Strategy 5: System Overload Navigation**
    ///
    /// Maximum sustainable input rate designed to overload the focus system
    /// and trigger defensive RunLoop stalls.
    ///
    /// **Implementation:**
    /// - Zero-delay inputs (system-limited maximum rate)
    /// - All four directions in rapid sequence
    /// - Sustained pressure for 10-15 second bursts
    /// - Brief recovery to allow stall manifestation
    func executeSystemOverloadNavigation(duration: TimeInterval) {
        NSLog("🚨 STRATEGY-5: System Overload Navigation (maximum input rate)")
        
        let endTime = Date().addingTimeInterval(duration)
        var overloadCount = 0
        
        let directions: [XCUIRemote.Button] = [.right, .up, .left, .down]
        
        while Date() < endTime {
            let overloadDuration = 10.0 + (Double(arc4random_uniform(6))) // 10-15 seconds
            let overloadEnd = Date().addingTimeInterval(overloadDuration)
            
            NSLog("🚨 Overload \(overloadCount + 1): \(String(format: "%.1f", overloadDuration))s maximum rate")
            
            var directionIndex = 0
            while Date() < overloadEnd {
                remote.press(directions[directionIndex], forDuration: 0.001)
                // NO usleep() - system-limited maximum rate
                
                directionIndex = (directionIndex + 1) % directions.count
            }
            
            overloadCount += 1
            
            // Recovery period to allow stall manifestation
            NSLog("🚨 Recovery pause - allowing stall manifestation")
            usleep(200_000) // 200ms recovery
        }
        
        NSLog("🚨 STRATEGY-5 Complete: \(overloadCount) overload sessions executed")
    }
    
    /// **Strategy 6: Combined Chaos Navigation**
    ///
    /// Combines elements from all previous strategies in unpredictable sequences
    /// to maximize system confusion and RunLoop stall probability.
    ///
    /// **Implementation:**
    /// - Random strategy selection every 10-20 seconds
    /// - Overlapping strategy execution
    /// - Progressive intensity increase
    /// - Maximum chaos approach
    func executeCombinedChaosNavigation(duration: TimeInterval) {
        NSLog("🎭 STRATEGY-6: Combined Chaos Navigation (all strategies mixed)")
        
        let endTime = Date().addingTimeInterval(duration)
        var chaosCount = 0
        
        while Date() < endTime {
            let miniDuration = 10.0 + (Double(arc4random_uniform(11))) // 10-20 seconds
            let strategy = Int(arc4random_uniform(5)) // 0-4 (strategies 1-5)
            
            NSLog("🎭 Chaos \(chaosCount + 1): Strategy \(strategy + 1) for \(String(format: "%.1f", miniDuration))s")
            
            switch strategy {
            case 0:
                executeRapidBurstNavigation(duration: miniDuration)
            case 1:
                executeSpiralChaosNavigation(duration: miniDuration)
            case 2:
                executeMicroStutterNavigation(duration: miniDuration)
            case 3:
                executeFocusThrashingNavigation(duration: miniDuration)
            case 4:
                executeSystemOverloadNavigation(duration: miniDuration)
            default:
                break
            }
            
            chaosCount += 1
        }
        
        NSLog("🎭 STRATEGY-6 Complete: \(chaosCount) chaos combinations executed")
    }
    
    /// Execute a spiral pattern navigation
    ///
    /// **Implementation Notes:**
    /// - Creates rectangular spiral pattern of specified size
    /// - Supports clockwise and counterclockwise directions
    /// - Variable timing to simulate human navigation uncertainty
    ///
    /// - Parameter size: Grid size for spiral (3-7)
    /// - Parameter clockwise: Direction of spiral movement
    func executeSpiralPattern(size: Int, clockwise: Bool) {
        let directions: [XCUIRemote.Button] = clockwise
            ? [.right, .down, .left, .up]
            : [.right, .up, .left, .down]
        
        var steps = [size - 1, size - 1, size - 1, size - 1] // Initial steps for each direction
        var currentDirection = 0
        
        for _ in 0..<4 { // Four sides of spiral
            let stepCount = steps[currentDirection]
            
            for _ in 0..<stepCount {
                remote.press(directions[currentDirection], forDuration: 0.01)
                usleep(UInt32(5_000 + arc4random_uniform(15_000))) // 5-20ms variable timing
            }
            
            currentDirection = (currentDirection + 1) % 4
            if currentDirection % 2 == 0 && steps[currentDirection] > 1 {
                steps[currentDirection] -= 1 // Shrink spiral inward
            }
        }
    }
}

// MARK: - V8.0 Implementation Extensions (Legacy)

extension FocusStressUITests {
    
    /// Execute natural right-heavy exploration with human-like timing irregularities
    ///
    /// **Implementation Notes:**
    /// - 60% right bias (matching successful manual reproduction)
    /// - Natural timing variation 40-250ms (vs uniform automated timing)
    /// - Progressive acceleration simulating increasing user frustration
    func executeNaturalRightHeavyExploration(duration: TimeInterval) {
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
    func executeProgressiveUpBurstAccumulation(duration: TimeInterval) {
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
    func executeSystemStressAcceleration(duration: TimeInterval) {
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
    func executeFocusedStressBurst(duration: TimeInterval) {
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
    func naturalHumanTiming(pressIndex: Int) -> UInt32 {
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

// MARK: - Console Log Capture for UITest Execution

extension FocusStressUITests {
    
    /// Sets up comprehensive console log capture for UITest execution
    /// Captures both XCUITest framework logs and application console output
    func setupComprehensiveConsoleCapture(testName: String) {
        // 1. Enable unified logging subsystem for filtering
        setupUnifiedLoggingSubsystem()
        
        // 2. Configure XCUIApplication to capture console output
        setupApplicationConsoleCapture()
        
        // 3. Set up log file capture in the application
        setupApplicationLogFileCapture(testName: testName)
        
        // 4. Configure verbose logging launch arguments
        setupVerboseLoggingArguments()
    }
    
    /// Configures unified logging subsystem for HammerTime app logs
    private func setupUnifiedLoggingSubsystem() {
        // Enable unified logging for our subsystem during test execution
        // These logs will appear in console and can be filtered by subsystem
        let logger = Logger(subsystem: "com.showblender.HammerTime", category: "UITestSetup")
        logger.info("UITest: Starting comprehensive console capture setup")
    }
    
    /// Configures XCUIApplication to capture application console output
    private func setupApplicationConsoleCapture() {
        // Launch arguments to enable verbose logging in the target app
        app.launchArguments.append("--enable-console-logging")
        app.launchArguments.append("--verbose-accessibility-logging")
        app.launchArguments.append("--capture-uitest-logs")
        
        // Environment variables for enhanced logging
        app.launchEnvironment["UITEST_EXECUTION"] = "TRUE"
        app.launchEnvironment["CONSOLE_LOGGING_ENABLED"] = "TRUE"
        app.launchEnvironment["AXFOCUS_DEBUGGER_VERBOSE"] = "TRUE"
    }
    
    /// Sets up log file capture in the target application
    private func setupApplicationLogFileCapture(testName: String) {
        // Pass the test name to the app so it can create appropriately named log files
        app.launchEnvironment["UITEST_NAME"] = testName
        app.launchEnvironment["UITEST_START_TIME"] = ISO8601DateFormatter().string(from: Date())
        
        // Enable TestRunLogger auto-start
        app.launchEnvironment["AUTO_START_TEST_LOGGER"] = "TRUE"
    }
    
    /// Configures verbose logging launch arguments
    private func setupVerboseLoggingArguments() {
        // Enable all debugging output
        app.launchArguments.append("--log-level=debug")
        app.launchArguments.append("--ax-debug-enabled")
        app.launchArguments.append("--infinity-bug-detection-enabled")
        
        // Ensure NSLog output is captured
        app.launchEnvironment["NS_LOGGING_ENABLED"] = "TRUE"
    }
}

// MARK: - Console Output Monitoring

extension FocusStressUITests {
    
    /// Monitors console output during test execution using unified logging
    func startConsoleMonitoring(testName: String) {
        let logger = Logger(subsystem: "com.showblender.HammerTime", category: "UITestMonitoring")
        logger.info("UITest: Starting console monitoring for test: \(testName, privacy: .public)")
        
        // Log test execution metadata
        logger.info("UITest: Device: \(UIDevice.current.name, privacy: .public)")
        logger.info("UITest: OS: \(UIDevice.current.systemName, privacy: .public) \(UIDevice.current.systemVersion, privacy: .public)")
        logger.info("UITest: Test Bundle: \(Bundle(for: type(of: self)).bundleIdentifier ?? "unknown", privacy: .public)")
    }
    
    /// Logs a message specifically for UITest execution context
    func logUITestMessage(_ message: String) {
        let logger = Logger(subsystem: "com.showblender.HammerTime", category: "UITestExecution")
        logger.info("UITEST: \(message, privacy: .public)")
        
        // Also log to XCTest for test output
        print("🧪 UITest: \(message)")
    }
    
    /// Stops console monitoring and logs summary
    func stopConsoleMonitoring(testName: String, success: Bool) {
        let logger = Logger(subsystem: "com.showblender.HammerTime", category: "UITestMonitoring")
        logger.info("UITest: Completed console monitoring for test: \(testName, privacy: .public)")
        logger.info("UITest: Result: \(success ? "SUCCESS" : "FAILURE", privacy: .public)")
        
        // Signal the app to stop logging
        if app.state == .runningForeground {
            // Send notification to app to finalize logs
            // The app should be listening for this environment variable change
        }
    }
}

// MARK: - Device Console Access

extension FocusStressUITests {
    
    /// Instructions for accessing device console logs after test execution
    func printConsoleAccessInstructions(testName: String) {
        print("""
        
        📱 CONSOLE LOG ACCESS INSTRUCTIONS for test: \(testName)
        
        ## Method 1: Xcode Console (Real-time)
        1. Open Xcode → Window → Devices and Simulators
        2. Select your Apple TV device
        3. Click "Open Console" 
        4. Filter by subsystem: "com.showblender.HammerTime"
        5. Run your test and view real-time logs
        
        ## Method 2: Console App (macOS)
        1. Open Console.app on your Mac
        2. Select your Apple TV device in sidebar
        3. Search for "com.showblender.HammerTime" or "TestRunLogger"
        4. View unified logs with timestamps
        
        ## Method 3: Device Log Files
        1. App logs saved to: Documents/HammerTimeLogs/
        2. Access via Xcode → Window → Devices and Simulators
        3. Select device → Installed Apps → HammerTime → Download Container
        4. Extract and navigate to Documents/HammerTimeLogs/
        
        ## Method 4: Terminal Log Streaming (Advanced)
        ```bash
        # Stream live logs from device
        xcrun devicectl log stream --device [DEVICE-ID] --predicate 'subsystem == "com.showblender.HammerTime"'
        
        # Collect logs for specific time period
        xcrun devicectl log collect --device [DEVICE-ID] --start "2025-06-25 10:00:00" --output uitest-logs.logarchive
        ```
        
        ## Filtering Console Output
        - TestRunLogger: category="TestRunLogger"
        - AXFocusDebugger: category="AXFocusDebugger" 
        - UITest Framework: category="UITestExecution"
        - All HammerTime: subsystem="com.showblender.HammerTime"
        
        """)
    }
}
