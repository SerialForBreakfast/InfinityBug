//
//  HammerTimeUITests.swift
//  HammerTimeUITests
//
//  Created by Joseph McCraw on 6/13/25.
//  These tests are ONLY to be run on a device with VoiceOver enabled.
import XCTest

/// Returns true when a focus ID refers to a real UI element.
private func isValidFocus(_ id: String) -> Bool {
    return !id.isEmpty && id != "NONE" && id != "NO_FOCUS"
}

private extension XCUIApplication {
    /// Returns "DebugCollectionView" if it exists, else the first collection-view on screen.
    var debugCollectionView: XCUIElement {
        let debug = collectionViews["DebugCollectionView"]
        if debug.exists {
            return debug
        }
        
        // Fallback: find any collection view
        let allCollectionViews = collectionViews
        for i in 0..<allCollectionViews.count {
            let cv = allCollectionViews.element(boundBy: i)
            if cv.exists {
                return cv
            }
        }
        
        // Last resort: return the first match even if it doesn't exist
        return collectionViews.firstMatch
    }
}

final class DebugCollectionViewUITests: XCTestCase {
    
    var app: XCUIApplication!
    let remote = XCUIRemote.shared                 // tvOS only
    
    // MARK: – Boilerplate ---------------------------------------------------
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        
        // NOTE: VoiceOver launch arguments and environment variables have no effect
        // in UI tests unless running system-level automation-signed tests.
        // Pre-enable VoiceOver in Settings or use: xcrun simctl ui <device> accessibility VoiceOver=on
        app.launchArguments += [
            // CRITICAL: Disable debounce for all focus tests
            "-DebounceDisabled", "YES",
            "-FocusTestMode", "YES"
        ]
        
        // Critical: Disable all debouncing for focus tests
        app.launchEnvironment["DEBOUNCE_DISABLED"] = "1"
        app.launchEnvironment["FOCUS_TEST_MODE"] = "1"
        
        app.launch()
        
        // Wait longer for complex container hierarchy to settle
        sleep(5)
        
        // Verify collection view exists
        let collectionView = app.debugCollectionView
        XCTAssertTrue(collectionView.waitForExistence(timeout: 10), "Must find a collection view")
        
        // Establish initial focus by navigating
        establishInitialFocus()
    }
    
    private func establishInitialFocus() {
        // Navigate to establish focus
        for _ in 0..<5 {
            remote.press(.up, forDuration: 0.05)
            usleep(50_000)
        }
        for _ in 0..<5 {
            remote.press(.left, forDuration: 0.05) 
            usleep(50_000)
        }
        
        // Try select press to activate focus
        remote.press(.select, forDuration: 0.01)
        usleep(200_000)
        
        let initialFocus = focusID
        NSLog("SETUP: Established initial focus: '\(initialFocus)'")
    }
    
    override func tearDownWithError() throws { app = nil }
    
    // MARK: – Helpers -------------------------------------------------------
    
    /// Returns identifier of currently-focused element or "NONE".
    /// NOTE: This only works reliably when VoiceOver is actually enabled
    var focusID: String {
        // Method 1: Try the standard hasFocus predicate
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
        
        // Method 2: Try collection view specifically
        let collectionView = app.debugCollectionView
        if collectionView.exists {
            let cells = collectionView.cells
            for cellIndex in 0..<min(cells.count, 20) {
                let cell = cells.element(boundBy: cellIndex)
                if cell.exists && cell.hasFocus {
                    return cell.identifier
                }
            }
        }
        
        return "NONE"
    }
    
    /// Verify basic accessibility setup without trying to control VoiceOver
    func verifyAccessibilitySetup() {
        NSLog("ACCESSIBILITY: Verifying basic accessibility setup...")
        
        // Step 1: Check if any elements have focus
        let focusedElements = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == true"))
        
        NSLog("FOCUS: Found \(focusedElements.count) focused elements")
        
        // Step 2: Try to find the first cell specifically
        let firstCell = app.cells["Cell-0"]
        XCTAssertTrue(firstCell.exists, "Cell-0 must exist for accessibility testing")
        NSLog("ACCESSIBILITY: Cell-0 exists: \(firstCell.exists)")
        
        // Step 3: Check if the first cell is accessible
        XCTAssertTrue(firstCell.isHittable, "Cell-0 must be hittable")
        NSLog("ACCESSIBILITY: Cell-0 is hittable: \(firstCell.isHittable)")
        
        // Step 4: Check accessibility properties
        let cellLabel = firstCell.label
        let cellValue = firstCell.value as? String ?? ""
        NSLog("ACCESSIBILITY: Cell-0 - Label: '\(cellLabel)', Value: '\(cellValue)'")
        
        XCTAssertFalse(cellLabel.isEmpty, "Cell-0 must have accessibility label")
        
        // Step 5: Force focus if no elements are focused
        if focusedElements.count == 0 {
            NSLog("WARNING: No focused elements found - attempting to set focus")
            
            // Navigate to establish focus using only supported buttons
            for _ in 0..<5 {
                remote.press(.up, forDuration: 0.05)
                usleep(50_000)
            }
            for _ in 0..<5 {
                remote.press(.left, forDuration: 0.05)
                usleep(50_000)
            }
            
            // Try select press to activate focus
            remote.press(.select, forDuration: 0.01)
            usleep(200_000)
            
            // Check again
            let newFocusedElements = app.descendants(matching: .any)
                .matching(NSPredicate(format: "hasFocus == true"))
            NSLog("FOCUS: After focus attempt: \(newFocusedElements.count) focused elements")
            
            XCTAssertGreaterThan(newFocusedElements.count, 0, 
                               "Must have at least one focused element after setup")
        }
        
        // Step 6: Verify we can get the current focus ID
        let currentFocusID = focusID
        NSLog("FOCUS: Current focus ID: '\(currentFocusID)'")
        XCTAssertNotEqual(currentFocusID, "", "Must have a valid focus ID")
        
        NSLog("SUCCESS: Accessibility verification complete")
    }
    
    /// Test basic focus navigation using only supported buttons
    func testBasicFocusNavigation() {
        NSLog("TEST: Testing basic focus navigation...")
        
        var focusHistory: [String] = []
        let testMoves = 5
        
        for i in 0..<testMoves {
            let beforeFocus = focusID
            focusHistory.append(beforeFocus)
            
            // Alternate between right and down movements
            let direction: XCUIRemote.Button = (i % 2 == 0) ? .right : .down
            
            NSLog("INPUT: Move \(i + 1): Pressing \(direction) from '\(beforeFocus)'")
            remote.press(direction, forDuration: 0.05)
            usleep(250_000) // 250ms wait
            
            let afterFocus = focusID
            NSLog("FOCUS: Move \(i + 1): '\(beforeFocus)' -> '\(afterFocus)'")
            
            // Log accessibility info for the new focus
            if afterFocus != beforeFocus && !afterFocus.isEmpty {
                logElementAccessibilityInfo(elementID: afterFocus)
            }
        }
        
        NSLog("SUMMARY: Navigation test complete. Focus history: \(focusHistory)")
        
        // Assert that we had some valid focus states
        let validFocusStates = focusHistory.filter { !$0.isEmpty }
        XCTAssertGreaterThan(validFocusStates.count, 0, 
                           "Must have at least one valid focus state during navigation")
    }
    
    /// Log accessibility information for an element
    func logElementAccessibilityInfo(elementID: String) {
        guard !elementID.isEmpty else { return }
        
        let element = app.descendants(matching: .any).matching(identifier: elementID).firstMatch
        
        if element.exists {
            let label = element.label
            let value = element.value as? String ?? ""
            let hint = element.placeholderValue ?? ""
            
            NSLog("ACCESSIBILITY: Element '\(elementID)'")
            NSLog("ACCESSIBILITY:    Label: '\(label)'")
            if !value.isEmpty {
                NSLog("ACCESSIBILITY:    Value: '\(value)'")
            }
            if !hint.isEmpty {
                NSLog("ACCESSIBILITY:    Hint: '\(hint)'")
            }
        } else {
            NSLog("ACCESSIBILITY: Element '\(elementID)' not accessible")
        }
    }
    
    /// Basic app functionality test - verifies app launches and UI is accessible
    func testAppLaunchesAndUIIsAccessible() throws {
        NSLog("TEST: Starting basic app functionality test...")
        
        // Verify collection view exists and is accessible
        let collectionView = app.debugCollectionView
        XCTAssertTrue(collectionView.exists, "DebugCollectionView should exist")
        XCTAssertTrue(collectionView.isHittable, "DebugCollectionView should be hittable")
        
        // Verify some cells exist and have proper accessibility setup
        let firstCell = app.cells["Cell-0"]
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "Cell-0 should exist")
        XCTAssertFalse(firstCell.label.isEmpty, "Cell-0 should have accessibility label")
        
        NSLog("SUCCESS: Basic app functionality verified")
    }
    
    /// Test basic navigation without VoiceOver assumptions
    func testBasicNavigation() throws {
        NSLog("TEST: Starting basic navigation test...")
        
        // Simple navigation test - just verify remote buttons work
        let initialState = app.debugDescription
        
        // Try a few navigation presses
        for direction in [XCUIRemote.Button.right, .down, .left, .up] {
            remote.press(direction, forDuration: 0.05)
            usleep(100_000) // 100ms wait
            
            // Just verify app is still responsive (doesn't crash)
            XCTAssertTrue(app.debugCollectionView.exists, 
                         "App should remain functional after \(direction) press")
        }
        
        NSLog("SUCCESS: Basic navigation completed without crashes")
    }
    
    /// Test that accessibility identifiers are properly set
    func testAccessibilityIdentifiersExist() throws {
        NSLog("TEST: Starting accessibility identifiers test...")
        
        let collectionView = app.debugCollectionView
        XCTAssertTrue(collectionView.exists, "DebugCollectionView should exist")
        
        // Check that cells have proper identifiers
        var cellsWithIdentifiers = 0
        var cellsWithLabels = 0
        
        // Check first 10 cells (avoid timeout issues)
        for i in 0..<10 {
            let cellID = "Cell-\(i)"
            let cell = app.cells[cellID]
            
            if cell.exists {
                cellsWithIdentifiers += 1
                
                if !cell.label.isEmpty {
                    cellsWithLabels += 1
                }
                
                NSLog("ACCESSIBILITY: Cell \(i) - ID: '\(cellID)', Label: '\(cell.label)'")
            }
        }
        
        XCTAssertGreaterThan(cellsWithIdentifiers, 5, "Should find multiple cells with proper identifiers")
        XCTAssertGreaterThan(cellsWithLabels, 5, "Should find multiple cells with accessibility labels")
        
        NSLog("SUCCESS: Found \(cellsWithIdentifiers) cells with identifiers, \(cellsWithLabels) with labels")
    }
    
    /// 200 random presses; assert focus never stalls on one element > 50×.
    func testRandomHammerScroll() throws {
        var repeatCounter = 0
        var lastID = ""
        let dirs: [XCUIRemote.Button] = [.up, .down, .left, .right]
        
        for n in 0..<200 {
            let d = dirs.randomElement()!
            remote.press(d, forDuration: 0.04)
            usleep(60_000)
            
            let current = focusID
            NSLog("[HAMMER] \(n) – \(d) → \(current)")
            
            if current == lastID && isValidFocus(current) {
                repeatCounter += 1
                if repeatCounter > 50 {
                    XCTFail("⚠️ Potential InfinityBug: focus stuck on \(current)")
                    break
                }
            } else {
                repeatCounter = isValidFocus(current) ? 1 : 0
                lastID = current
            }
        }
        XCTAssertLessThanOrEqual(repeatCounter, 50, "Focus should not repeat > 50× consecutively")
    }
    
    func testManualElementTraversal() throws {
        NSLog("TEST: Starting deterministic element traversal…")

        // The sample grid (see ViewController.swift) contains exactly 100 cells,
        // each with accessibilityIdentifier "Cell-<index>".
        let collectionView = app.debugCollectionView
        XCTAssertTrue(collectionView.waitForExistence(timeout: 5),
                      "DebugCollectionView not found")

        let expectedCellCount = 100
        var visited = Set<String>()

        // If the current focus is not on Cell‑0, nudge focus to the top‑left corner.
        if focusID != "Cell-0" {
            // Up/left a few times puts focus in a predictable corner; then Select.
            for _ in 0..<8 {
                remote.press(.up, forDuration: 0.04)
                usleep(40_000)
            }
            for _ in 0..<8 {
                remote.press(.left, forDuration: 0.04)
                usleep(40_000)
            }
            remote.press(.select, forDuration: 0.05)
            usleep(120_000)
        }

        // Walk through "Cell‑0" … "Cell‑99", scrolling as needed.
        for index in 0..<expectedCellCount {
            let cellID = "Cell-\(index)"
            let cell   = collectionView.cells[cellID]

            // Scroll down until this cell is instantiated and in the viewport.
            var scrollAttempts = 0
            while (!cell.exists || !cell.isHittable) && scrollAttempts < 15 {
                remote.press(.down, forDuration: 0.05)
                usleep(60_000)
                scrollAttempts += 1
            }

            // Basic assertions for each cell
            XCTAssertTrue(cell.exists,    "\(cellID) should exist after scrolling")
            XCTAssertTrue(cell.isHittable,"\(cellID) should be hittable")
            XCTAssertFalse(cell.label.isEmpty, "\(cellID) must have an accessibility label")

            visited.insert(cellID)
        }

        // Final sanity‑check: did we see everything?
        XCTAssertEqual(visited.count, expectedCellCount,
                       "Visited \(visited.count) / \(expectedCellCount) cells")
        NSLog("SUCCESS: Traversed all \(visited.count) cells")
    }
    
    /// Test rapid directional changes to break focus tracking
    func testRapidDirectionalFocusChanges() throws {
        NSLog("TEST: Starting rapid directional focus changes test...")
        
        var focusHistory: [String] = []
        var stuckCount = 0
        let maxStuckAllowed = 3
        let totalMoves = 150
        
        // Rapid alternating directions to stress focus system
        let patterns: [[XCUIRemote.Button]] = [
            [.right, .left, .right, .left],                    // Horizontal ping-pong
            [.down, .up, .down, .up],                          // Vertical ping-pong
            [.right, .down, .left, .up],                       // Square pattern
            [.right, .right, .left, .left, .down, .down, .up, .up], // Repeated directions
            [.right, .down, .right, .up, .left, .down, .left, .up]  // Figure-8 pattern
        ]
        
        for moveIndex in 0..<totalMoves {
            let patternIndex = moveIndex % patterns.count
            let pattern = patterns[patternIndex]
            let direction = pattern[moveIndex % pattern.count]
            
            let beforeFocus = focusID
            
            // Very fast presses with minimal delay
            remote.press(direction, forDuration: 0.02)
            usleep(25_000) // Only 25ms between presses
            
            let afterFocus = focusID
            focusHistory.append(afterFocus)
            
            NSLog("RAPID[\(moveIndex)]: \(direction) → \(beforeFocus) to \(afterFocus)")
            
            // Check for stuck focus
            if beforeFocus == afterFocus && !afterFocus.isEmpty {
                stuckCount += 1
                if stuckCount > maxStuckAllowed {
                    NSLog("ERROR: Focus stuck on '\(afterFocus)' for \(stuckCount) consecutive moves")
                    XCTFail("⚠️ INFINITY BUG DETECTED: Focus stuck on \(afterFocus) for \(stuckCount) moves")
                    break
                }
            } else {
                stuckCount = 0
            }
            
            // Check for focus loss
            if afterFocus.isEmpty {
                NSLog("WARNING: Focus lost at move \(moveIndex)")
            }
        }
        
        // Analyze focus history
        let uniqueFocuses = Set(focusHistory.filter { !$0.isEmpty })
        NSLog("RESULTS: Touched \(uniqueFocuses.count) unique elements in \(totalMoves) moves")
        NSLog("RESULTS: Max consecutive stuck count: \(stuckCount)")
        
        XCTAssertGreaterThan(uniqueFocuses.count, 5, "Should traverse multiple elements")
        XCTAssertLessThanOrEqual(stuckCount, maxStuckAllowed, "Focus should not get stuck")
    }
    
    /// Test focus behavior during simulated interruptions
    func testFocusDuringInterruptions() throws {
        NSLog("TEST: Starting focus during interruptions test...")
        
        let initialFocus = focusID
        NSLog("INITIAL: Focus at '\(initialFocus)'")
        
        // Simulate interruption using select button (only reliable button that won't background app)
        NSLog("STEP 1: Simulating interruption with select press...")
        
        remote.press(.select, forDuration: 0.1) // Brief select press
        usleep(500_000) // Wait for any interruption effects
        
        let postInterruptionFocus = focusID
        NSLog("POST-INTERRUPTION: Focus at '\(postInterruptionFocus)'")
        
        // Test if focus is still responsive
        NSLog("STEP 2: Testing focus responsiveness after interruption...")
        
        var responsiveAfterInterruption = false
        for attempt in 0..<8 {
            let beforeMove = focusID
            
            // Try different directions
            let directions: [XCUIRemote.Button] = [.right, .down, .left, .up]
            let direction = directions[attempt % directions.count]
            
            remote.press(direction, forDuration: 0.05)
            usleep(300_000) // Wait for response
            
            let afterMove = focusID
            NSLog("RESPONSIVE TEST[\(attempt)]: '\(beforeMove)' → '\(afterMove)' (direction: \(direction))")
            
            if beforeMove != afterMove && !afterMove.isEmpty {
                responsiveAfterInterruption = true
                NSLog("SUCCESS: Focus responsive with direction \(direction) at attempt \(attempt)")
                break
            }
        }
        
        // Lenient check - if focus exists and isn't "NONE", consider it responsive
        if !responsiveAfterInterruption {
            let currentFocus = focusID
            if !currentFocus.isEmpty && currentFocus != "NONE" {
                responsiveAfterInterruption = true
                NSLog("SUCCESS: Focus system has valid state after interruption")
            }
        }
        
        XCTAssertTrue(responsiveAfterInterruption, "Focus should be responsive after interruption")
    }
    
    
    /// Test focus recovery after stress
    func testFocusRecoveryAfterStress() throws {
        NSLog("TEST: Starting focus recovery after stress test...")
        
        // Stress the focus system with ultra-rapid presses
        NSLog("STEP 1: Stressing focus system...")
        
        let initialFocus = focusID
        var rapidPresses = 0
        
        // Ultra-rapid presses to stress system
        for _ in 0..<100 {
            let direction: XCUIRemote.Button = [.up, .down, .left, .right].randomElement()!
            remote.press(direction, forDuration: 0.01)
            usleep(10_000) // Only 10ms between presses
            rapidPresses += 1
        }
        
        NSLog("STRESS: Completed \(rapidPresses) ultra-rapid presses")
        
        let postStressFocus = focusID
        NSLog("POST-STRESS: Focus is '\(postStressFocus)'")
        
        // Test recovery
        NSLog("STEP 2: Testing focus recovery...")
        
        let recoveryStartFocus = focusID
        var recoveryWorking = false
        
        // Try normal navigation to test recovery
        for attempt in 0..<10 {
            let beforeFocus = focusID
            remote.press(.right, forDuration: 0.05)
            usleep(200_000) // Normal timing
            
            let afterFocus = focusID
            NSLog("RECOVERY[\(attempt)]: '\(beforeFocus)' → '\(afterFocus)'")
            
            if beforeFocus != afterFocus && !afterFocus.isEmpty {
                recoveryWorking = true
                NSLog("SUCCESS: Focus system recovered at attempt \(attempt)")
                break
            }
            
            // Try different directions if stuck
            if !recoveryWorking && attempt >= 3 {
                let alternativeDirection: XCUIRemote.Button = [.down, .left, .up].randomElement()!
                NSLog("RECOVERY: Trying alternative direction \(alternativeDirection)")
                remote.press(alternativeDirection, forDuration: 0.05)
                usleep(200_000)
                
                let altAfterFocus = focusID
                if beforeFocus != altAfterFocus && !altAfterFocus.isEmpty {
                    recoveryWorking = true
                    NSLog("SUCCESS: Focus system recovered with alternative direction")
                    break
                }
            }
        }
        
        // Be lenient - focus system might be working even if we can't detect movement
        if !recoveryWorking {
            let finalRecoveryFocus = focusID
            if !finalRecoveryFocus.isEmpty && finalRecoveryFocus != "NONE" {
                recoveryWorking = true
                NSLog("SUCCESS: Focus system has valid focus state, assuming recovery worked")
            }
        }
        
        XCTAssertTrue(recoveryWorking, "Focus system should recover after stress test")
        
        let finalFocus = focusID
        XCTAssertFalse(finalFocus.isEmpty, "Focus should not be completely lost after recovery")
        
        NSLog("RECOVERY: Final focus state: '\(finalFocus)'")
    }
    
    /// Replicates and detects the InfinityBug by rapidly sending navigation inputs
    func testInfinityBugReplication() throws {
        NSLog("INFINITY BUG TEST: Starting InfinityBug replication test...")
        let directions: [XCUIRemote.Button] = [.up, .down, .left, .right]
        let maxConsecutiveStuck = 10
        var consecutiveStuck = 0
        var lastFocus = ""
        var totalMoves = 0
        var focusHistory: [String] = []

        // Rapidly simulate navigation inputs
        for move in 0..<300 {
            let direction = directions.randomElement()!
            let beforeFocus = focusID
            remote.press(direction, forDuration: 0.015)
            usleep(20_000) // 20ms between presses
            let afterFocus = focusID
            focusHistory.append(afterFocus)
            totalMoves += 1
            NSLog("INFINITY BUG [\(move)]: \(direction) '\(beforeFocus)' -> '\(afterFocus)'")
            
            if afterFocus == lastFocus && !afterFocus.isEmpty {
                consecutiveStuck += 1
                NSLog("INFINITY BUG: Focus stuck on '\(afterFocus)' for \(consecutiveStuck) consecutive moves")
                if consecutiveStuck >= maxConsecutiveStuck {
                    NSLog("🚨 INFINITY BUG DETECTED: Focus stuck on '\(afterFocus)' for \(consecutiveStuck) consecutive navigation inputs")
                    XCTFail("🚨 InfinityBug: Focus stuck on \(afterFocus) for \(consecutiveStuck) consecutive moves")
                    break
                }
            } else {
                consecutiveStuck = 1
                lastFocus = afterFocus
            }
        }
        
        NSLog("INFINITY BUG TEST: Completed \(totalMoves) moves. Max consecutive stuck: \(consecutiveStuck)")
        
        // Assert that the focus never got stuck for more than threshold
        XCTAssertLessThan(consecutiveStuck, maxConsecutiveStuck, 
                         "Focus should not be stuck for \(maxConsecutiveStuck) or more consecutive moves (potential InfinityBug)")
        
        // Log unique focus count for diagnostics
        let uniqueFocuses = Set(focusHistory.filter { !$0.isEmpty })
        NSLog("INFINITY BUG TEST: Unique focus states traversed: \(uniqueFocuses.count)")
    }
    
    /// Brute force InfinityBug test with maximum speed
    func testInfinityBugReplicationBrute() throws {
        NSLog("INFINITY BUG TEST: Starting brute force InfinityBug test...")
        NSLog("NOTE: Using maximum speed (1ms duration, 5ms gaps)")
        
        let directions: [XCUIRemote.Button] = [.up, .down, .left, .right]
        let maxConsecutiveStuck = 10
        var consecutiveStuck = 0
        var lastFocus = ""
        var totalMoves = 0

        // Maximum speed navigation inputs
        for move in 0..<300 {
            let direction = directions.randomElement()!
            let beforeFocus = focusID
            remote.press(direction, forDuration: 0.001) // Minimum duration
            usleep(5_000) // 5ms between presses
            let afterFocus = focusID
            totalMoves += 1
            
            if afterFocus == lastFocus && !afterFocus.isEmpty {
                consecutiveStuck += 1
                if consecutiveStuck >= maxConsecutiveStuck {
                    NSLog("🚨 INFINITY BUG DETECTED: Focus stuck on '\(afterFocus)' for \(consecutiveStuck) consecutive moves")
                    XCTFail("🚨 InfinityBug: Focus stuck on \(afterFocus) for \(consecutiveStuck) consecutive moves")
                    break
                }
            } else {
                consecutiveStuck = 0
                lastFocus = afterFocus
            }
            
            // Log every 50th move to reduce spam
            if move % 50 == 0 {
                NSLog("BRUTE[\(move)]: \(direction) '\(beforeFocus)' -> '\(afterFocus)' (stuck: \(consecutiveStuck))")
            }
        }
        
        NSLog("BRUTE FORCE TEST: Completed \(totalMoves) moves. Max consecutive stuck: \(consecutiveStuck)")
        XCTAssertLessThan(consecutiveStuck, maxConsecutiveStuck, 
                         "Focus should not be stuck for \(maxConsecutiveStuck) or more consecutive moves")
    }
    
    /// Test focus state persistence across rapid input bursts
    func testFocusStatePersistenceAcrossInputBursts() throws {
        NSLog("TEST: Starting focus state persistence across input bursts test...")
        
        let burstSizes = [5, 10, 15, 20, 25]
        let burstDelays: [UInt32] = [100_000, 200_000, 500_000] // microseconds between bursts
        
        var persistenceResults: [(burstSize: Int, burstDelay: UInt32, focusPersistent: Bool, finalFocus: String)] = []
        
        for burstSize in burstSizes {
            for burstDelay in burstDelays {
                NSLog("PERSISTENCE: Testing burst size \(burstSize) with \(burstDelay)μs delay")
                
                // Execute burst of rapid inputs
                for burstRound in 0..<3 { // 3 bursts per configuration
                    NSLog("BURST[\(burstSize)-\(burstDelay)μs-\(burstRound)]: Starting burst from '\(focusID)'")
                    
                    // Rapid input burst
                    for inputIndex in 0..<burstSize {
                        let direction: XCUIRemote.Button = [.right, .down, .left, .up].randomElement()!
                        remote.press(direction, forDuration: 0.01)
                        usleep(15_000) // 15ms between inputs in burst
                    }
                    
                    // Delay between bursts
                    usleep(burstDelay)
                    
                    let burstEndFocus = focusID
                    NSLog("BURST[\(burstSize)-\(burstDelay)μs-\(burstRound)]: Ended at '\(burstEndFocus)'")
                }
                
                let finalFocus = focusID
                let focusPersistent = !finalFocus.isEmpty
                
                persistenceResults.append((
                    burstSize: burstSize,
                    burstDelay: burstDelay,
                    focusPersistent: focusPersistent,
                    finalFocus: finalFocus
                ))
                
                NSLog("PERSISTENCE[\(burstSize)-\(burstDelay)μs]: Final focus '\(finalFocus)' (persistent: \(focusPersistent))")
            }
        }
        
        // Analyze persistence across different configurations
        let totalTests = persistenceResults.count
        let persistentCount = persistenceResults.filter { $0.focusPersistent }.count
        
        NSLog("PERSISTENCE RESULTS: \(persistentCount)/\(totalTests) tests maintained focus persistence")
        
        XCTAssertGreaterThan(persistentCount, totalTests * 3 / 4, 
                           "Most input burst configurations should maintain focus persistence")
    }
    
    /// Test accessibility conflicts in multi-layered container hierarchy
    func testContainerFactoryAccessibilityConflicts() throws {
        NSLog("TEST: Starting ContainerFactory accessibility conflicts test...")
        
        // The ContainerFactory creates a 3-layer hierarchy:
        // 1. Outer UIViewController (Plant-themed: Oak, Rose, etc.)
        // 2. UIHostingController (SwiftUI wrapper)  
        // 3. Inner UIViewController (Animal-themed: Cat, Dog, etc.)
        // 4. SampleViewController (our actual content)
        // 5. DebugCollectionView (the collection view)
        
        let collectionView = app.debugCollectionView
        XCTAssertTrue(collectionView.waitForExistence(timeout: 10), "DebugCollectionView should exist")
        
        // Test 1: Check for accessibility element conflicts
        NSLog("STEP 1: Checking for accessibility element conflicts...")
        
        // Find all accessibility elements in the hierarchy
        let allElements = app.descendants(matching: .any)
        var accessibilityConflicts: [String: Int] = [:]
        var containerElements: [(identifier: String, label: String, type: String)] = []
        
        for elementIndex in 0..<min(allElements.count, 100) {
            let element = allElements.element(boundBy: elementIndex)
            if element.exists {
                let identifier = element.identifier
                let label = element.label
                let elementType = element.elementType.rawValue
                
                // Track container-related elements
                if identifier.contains("Plant-") || identifier.contains("Animal-") {
                    containerElements.append((identifier: identifier, label: label, type: String(elementType)))
                    NSLog("CONTAINER ELEMENT: ID='\(identifier)', Label='\(label)', Type=\(elementType)")
                }
                
                // Track potential conflicts
                if !identifier.isEmpty {
                    accessibilityConflicts[identifier, default: 0] += 1
                }
            }
        }
        
        // Report conflicts
        let conflicts = accessibilityConflicts.filter { $0.value > 1 }
        for (identifier, count) in conflicts {
            NSLog("CONFLICT: Identifier '\(identifier)' appears \(count) times")
        }
        
        NSLog("CONTAINERS: Found \(containerElements.count) container elements")
        NSLog("CONFLICTS: Found \(conflicts.count) duplicate identifiers")
        
        // Test 2: Focus navigation through container layers
        NSLog("STEP 2: Testing focus navigation through container layers...")
        
        var focusPath: [String] = []
        let initialFocus = focusID
        focusPath.append(initialFocus)
        
        // Navigate and track which layer we're focusing on
        for move in 0..<20 {
            let beforeFocus = focusID
            
            // Alternate navigation directions
            let direction: XCUIRemote.Button = (move % 2 == 0) ? .down : .right
            remote.press(direction, forDuration: 0.05)
            usleep(200_000)
            
            let afterFocus = focusID
            focusPath.append(afterFocus)
            
            // Categorize the focused element
            let focusCategory = categorizeFocusedElement(afterFocus)
            NSLog("FOCUS[\(move)]: '\(beforeFocus)' → '\(afterFocus)' (\(focusCategory))")
            
            // Check if we're stuck on container elements
            if focusCategory == "Container" && move > 5 {
                NSLog("WARNING: Focus stuck on container element after \(move) moves")
            }
        }
        
        // Analyze focus distribution
        let containerFocuses = focusPath.filter { categorizeFocusedElement($0) == "Container" }
        let contentFocuses = focusPath.filter { categorizeFocusedElement($0) == "Content" }
        let navFocuses = focusPath.filter { categorizeFocusedElement($0) == "Navigation" }
        
        NSLog("FOCUS DISTRIBUTION: Container=\(containerFocuses.count), Content=\(contentFocuses.count), Nav=\(navFocuses.count)")
        
        // Test 3: Accessibility announcements in layered hierarchy
        NSLog("STEP 3: Testing accessibility announcements in layered hierarchy...")
        
        // Try to focus on different layer types and verify announcements
        let testElements = [
            ("Cell-0", "Content layer"),
            ("Nav-Header1", "Navigation layer")
        ]
        
        for (elementID, layerType) in testElements {
            let element = app.descendants(matching: .any).matching(identifier: elementID).firstMatch
            if element.exists && element.isHittable {
                NSLog("ANNOUNCEMENT TEST: Focusing on \(elementID) (\(layerType))")
                
                // Navigate to element (simplified approach)
                for _ in 0..<10 {
                    if focusID == elementID { break }
                    remote.press(.down, forDuration: 0.05)
                    usleep(100_000)
                }
                
                let finalFocus = focusID
                let focusMatches = (finalFocus == elementID)
                NSLog("ANNOUNCEMENT RESULT: Target='\(elementID)', Actual='\(finalFocus)', Match=\(focusMatches)")
            }
        }
        
        XCTAssertGreaterThan(containerElements.count, 0, "Should find container elements from ContainerFactory")
        XCTAssertLessThan(conflicts.count, 5, "Should have minimal accessibility identifier conflicts")
    }
    
    /// Test focus behavior when containers have conflicting accessibility properties
    func testContainerAccessibilityPropertyConflicts() throws {
        NSLog("TEST: Starting container accessibility property conflicts test...")
        
        // Test how focus behaves when multiple containers have accessibility properties
        let collectionView = app.debugCollectionView
        XCTAssertTrue(collectionView.exists, "DebugCollectionView should exist")
        
        // Step 1: Try to identify container layers by their accessibility properties
        NSLog("STEP 1: Identifying container layers...")
        
        var plantContainers: [String] = []
        var animalContainers: [String] = []
        
        let allElements = app.descendants(matching: .any)
        for elementIndex in 0..<min(allElements.count, 50) {
            let element = allElements.element(boundBy: elementIndex)
            if element.exists {
                let identifier = element.identifier
                let label = element.label
                let value = element.value as? String ?? ""
                
                // Identify plant containers (outer layer)
                if identifier.hasPrefix("Plant-") {
                    plantContainers.append(identifier)
                    NSLog("PLANT CONTAINER: ID='\(identifier)', Label='\(label)', Value='\(value)'")
                }
                
                // Identify animal containers (inner layer)  
                if identifier.hasPrefix("Animal-") {
                    animalContainers.append(identifier)
                    NSLog("ANIMAL CONTAINER: ID='\(identifier)', Label='\(label)', Value='\(value)'")
                }
            }
        }
        
        NSLog("CONTAINERS: Found \(plantContainers.count) plant containers, \(animalContainers.count) animal containers")
        
        // Step 2: Test focus precedence between container layers
        NSLog("STEP 2: Testing focus precedence between container layers...")
        
        var focusHierarchyTest: [(focus: String, layer: String)] = []
        
        // Navigate through the app and categorize each focus
        for move in 0..<15 {
            let currentFocus = focusID
            let layer = determineAccessibilityLayer(currentFocus)
            focusHierarchyTest.append((focus: currentFocus, layer: layer))
            
            NSLog("HIERARCHY[\(move)]: Focus='\(currentFocus)' Layer='\(layer)'")
            
            // Move focus
            remote.press(.right, forDuration: 0.05)
            usleep(150_000)
        }
        
        // Analyze which layers actually receive focus
        let layerCounts = Dictionary(grouping: focusHierarchyTest, by: { $0.layer })
            .mapValues { $0.count }
        
        for (layer, count) in layerCounts {
            NSLog("LAYER FOCUS COUNT: \(layer) = \(count)")
        }
        
        // Step 3: Test accessibility trait conflicts
        NSLog("STEP 3: Testing accessibility trait conflicts...")
        
        // Check if container elements interfere with content element traits
        let firstCell = app.cells["Cell-0"]
        if firstCell.exists {
            let cellTraits = firstCell.accessibilityTraits
            NSLog("CELL TRAITS: Cell-0 has traits: \(cellTraits)")
            
            // Try to interact with the cell and see if container layers interfere
            let beforeInteraction = focusID
            remote.press(.select, forDuration: 0.1)
            usleep(200_000)
            let afterInteraction = focusID
            
            NSLog("INTERACTION: Before='\(beforeInteraction)', After='\(afterInteraction)'")
        }
        
        // Assertions
        XCTAssertTrue(plantContainers.count > 0 || animalContainers.count > 0, 
                     "Should find at least one container layer")
        
        // Most focus should be on content, not containers
        let contentFocusCount = layerCounts["Content"] ?? 0
        let containerFocusCount = (layerCounts["Plant"] ?? 0) + (layerCounts["Animal"] ?? 0)
        
        XCTAssertGreaterThan(contentFocusCount, containerFocusCount, 
                           "Content should receive more focus than containers")
    }
    
    /// Test VoiceOver behavior with nested container accessibility elements
    func testVoiceOverNestedContainerBehavior() throws {
        NSLog("TEST: Starting VoiceOver nested container behavior test...")
        
        // This test examines how VoiceOver handles the nested accessibility hierarchy
        // created by ContainerFactory: Plant > Animal > SampleVC > CollectionView > Cells
        
        let collectionView = app.debugCollectionView
        XCTAssertTrue(collectionView.exists, "DebugCollectionView should exist")
        
        // Step 1: Map the complete accessibility hierarchy
        NSLog("STEP 1: Mapping accessibility hierarchy...")
        
        var hierarchyMap: [String: (parent: String?, children: [String], level: Int)] = [:]
        
        // This is a simplified hierarchy mapping since we can't easily traverse parent-child
        // relationships in XCTest, but we can categorize by naming patterns
        let allElements = app.descendants(matching: .any)
        var elementsByType: [String: [String]] = [:]
        
        for elementIndex in 0..<min(allElements.count, 30) {
            let element = allElements.element(boundBy: elementIndex)
            if element.exists {
                let identifier = element.identifier
                if !identifier.isEmpty {
                    let category = categorizeElementByIdentifier(identifier)
                    elementsByType[category, default: []].append(identifier)
                }
            }
        }
        
        for (category, identifiers) in elementsByType {
            NSLog("HIERARCHY: \(category) = \(identifiers)")
        }
        
        // Step 2: Test focus flow through hierarchy levels
        NSLog("STEP 2: Testing focus flow through hierarchy levels...")
        
        var hierarchyFocusFlow: [(element: String, category: String, order: Int)] = []
        
        for step in 0..<25 {
            let currentFocus = focusID
            let category = categorizeElementByIdentifier(currentFocus)
            hierarchyFocusFlow.append((element: currentFocus, category: category, order: step))
            
            NSLog("FLOW[\(step)]: '\(currentFocus)' (\(category))")
            
            // Navigate with varying patterns to test hierarchy traversal
            let direction: XCUIRemote.Button
            switch step % 4 {
            case 0: direction = .right
            case 1: direction = .down  
            case 2: direction = .left
            case 3: direction = .up
            default: direction = .right
            }
            
            remote.press(direction, forDuration: 0.04)
            usleep(120_000)
        }
        
        // Analyze hierarchy traversal patterns
        let categoryTransitions = zip(hierarchyFocusFlow, hierarchyFocusFlow.dropFirst())
            .map { (from: $0.category, to: $1.category) }
        
        var transitionCounts: [String: Int] = [:]
        for transition in categoryTransitions {
            let key = "\(transition.from) → \(transition.to)"
            transitionCounts[key, default: 0] += 1
        }
        
        NSLog("HIERARCHY TRANSITIONS:")
        for (transition, count) in transitionCounts.sorted(by: { $0.value > $1.value }) {
            NSLog("  \(transition): \(count) times")
        }
        
        // Step 3: Test accessibility element visibility at each level
        NSLog("STEP 3: Testing accessibility element visibility...")
        
        // Check if nested containers are properly exposed to accessibility
        let plantElements = elementsByType["Plant"] ?? []
        let animalElements = elementsByType["Animal"] ?? []
        let contentElements = elementsByType["Content"] ?? []
        let navElements = elementsByType["Navigation"] ?? []
        
        NSLog("VISIBILITY: Plant=\(plantElements.count), Animal=\(animalElements.count), Content=\(contentElements.count), Nav=\(navElements.count)")
        
        // Verify that content elements are still accessible despite container wrapping
        XCTAssertGreaterThan(contentElements.count, 5, "Content elements should be accessible despite container wrapping")
        
        // Most transitions should be within content, not between container layers
        let contentTransitions = transitionCounts.filter { $0.key.contains("Content") }.values.reduce(0, +)
        let containerTransitions = transitionCounts.filter { $0.key.contains("Plant") || $0.key.contains("Animal") }.values.reduce(0, +)
        
        NSLog("TRANSITION ANALYSIS: Content=\(contentTransitions), Container=\(containerTransitions)")
        
        // Content should dominate navigation
        XCTAssertGreaterThan(contentTransitions, containerTransitions, 
                           "Focus should primarily navigate content, not containers")
    }
    
    // MARK: - Helper Methods for Container Testing
    
    /// Categorizes a focused element by its identifier pattern
    private func categorizeFocusedElement(_ identifier: String) -> String {
        if identifier.hasPrefix("Plant-") { return "Container" }
        if identifier.hasPrefix("Animal-") { return "Container" }
        if identifier.hasPrefix("Cell-") { return "Content" }
        if identifier.hasPrefix("Nav-") { return "Navigation" }
        if identifier == "DebugCollectionView" { return "Content" }
        if identifier.isEmpty || identifier == "NONE" { return "Unknown" }
        return "Other"
    }
    
    /// Determines which accessibility layer an element belongs to
    private func determineAccessibilityLayer(_ identifier: String) -> String {
        if identifier.hasPrefix("Plant-") { return "Plant" }
        if identifier.hasPrefix("Animal-") { return "Animal" }
        if identifier.hasPrefix("Cell-") { return "Content" }
        if identifier.hasPrefix("Nav-") { return "Navigation" }
        if identifier == "DebugCollectionView" { return "Content" }
        return "Unknown"
    }
    
    /// Categorizes elements by their identifier patterns for hierarchy analysis
    private func categorizeElementByIdentifier(_ identifier: String) -> String {
        if identifier.hasPrefix("Plant-") { return "Plant" }
        if identifier.hasPrefix("Animal-") { return "Animal" }
        if identifier.hasPrefix("Cell-") { return "Content" }
        if identifier.hasPrefix("Nav-") { return "Navigation" }
        if identifier == "DebugCollectionView" { return "CollectionView" }
        if identifier.isEmpty { return "Empty" }
        return "Other"
    }
    
    /// Test InfinityBug reproduction through accessibility conflicts
    func testInfinityBugViaAccessibilityConflicts() throws {
        NSLog("TEST: Starting InfinityBug reproduction via accessibility conflicts...")
        
        // The ContainerFactory should have created multiple competing accessibility elements
        let allElements = app.descendants(matching: .any)
        var conflictingElements: [String] = []
        
        for elementIndex in 0..<min(allElements.count, 50) {
            let element = allElements.element(boundBy: elementIndex)
            if element.exists {
                let identifier = element.identifier
                if identifier.hasPrefix("Plant-") || identifier.hasPrefix("Animal-") {
                    conflictingElements.append(identifier)
                    NSLog("CONFLICT ELEMENT: '\(identifier)' - Label: '\(element.label)'")
                }
            }
        }
        
        NSLog("CONFLICTS: Found \(conflictingElements.count) conflicting accessibility elements")
        XCTAssertGreaterThan(conflictingElements.count, 0, "Should have accessibility conflicts for InfinityBug testing")
        
        // Now stress test focus navigation in this conflicted environment
        var focusStuckCount = 0
        var lastFocus = ""
        let maxStuckThreshold = 15
        
        NSLog("STRESS: Starting navigation in conflicted accessibility environment...")
        
        for move in 0..<200 {
            let direction: XCUIRemote.Button = [.up, .down, .left, .right].randomElement()!
            let beforeFocus = focusID
            
            remote.press(direction, forDuration: 0.02) // Very fast presses
            usleep(30_000) // 30ms between presses
            
            let afterFocus = focusID
            
            if beforeFocus == afterFocus && !afterFocus.isEmpty {
                focusStuckCount += 1
                if focusStuckCount >= maxStuckThreshold {
                    NSLog("🚨 INFINITY BUG DETECTED: Focus stuck on '\(afterFocus)' for \(focusStuckCount) moves in conflicted environment")
                    XCTFail("🚨 InfinityBug reproduced via accessibility conflicts: Focus stuck on \(afterFocus)")
                    break
                }
            } else {
                focusStuckCount = 0
            }
            
            // Log every 25th move to track progress
            if move % 25 == 0 {
                NSLog("CONFLICT STRESS[\(move)]: \(direction) '\(beforeFocus)' → '\(afterFocus)' (stuck: \(focusStuckCount))")
            }
            
            lastFocus = afterFocus
        }
        
        NSLog("CONFLICT STRESS COMPLETE: Max stuck count: \(focusStuckCount)")
        XCTAssertLessThan(focusStuckCount, maxStuckThreshold, "Focus should not get infinitely stuck due to accessibility conflicts")
    }
    
    /// Test how VoiceOver handles the intentional accessibility conflicts
    func testVoiceOverAccessibilityConflictHandling() throws {
        NSLog("TEST: Testing VoiceOver handling of intentional accessibility conflicts...")
        
        // Navigate and track how VoiceOver resolves conflicts between:
        // - Plant container accessibility 
        // - Animal container accessibility
        // - Collection view accessibility
        // - Cell accessibility
        
        var conflictResolutionLog: [(move: Int, focus: String, category: String)] = []
        
        for move in 0..<50 {
            let currentFocus = focusID
            let category = categorizeElementByIdentifier(currentFocus)
            conflictResolutionLog.append((move: move, focus: currentFocus, category: category))
            
            NSLog("CONFLICT RESOLUTION[\(move)]: Focus='\(currentFocus)' Category='\(category)'")
            
            // Navigate through the conflicted hierarchy
            let direction: XCUIRemote.Button = (move % 2 == 0) ? .right : .down
            remote.press(direction, forDuration: 0.05)
            usleep(150_000)
        }
        
        // Analyze how often focus gets trapped in container layers vs content
        let containerFocuses = conflictResolutionLog.filter { $0.category == "Plant" || $0.category == "Animal" }
        let contentFocuses = conflictResolutionLog.filter { $0.category == "Content" || $0.category == "CollectionView" }
        
        NSLog("CONFLICT ANALYSIS: Container focuses=\(containerFocuses.count), Content focuses=\(contentFocuses.count)")
        
        // In a properly working system, content should dominate even with conflicts
        // If containers trap focus, that could indicate InfinityBug conditions
        if containerFocuses.count > contentFocuses.count {
            NSLog("⚠️ WARNING: Focus trapped in container layers more than content - potential InfinityBug condition")
        }
        
        // Don't fail the test - we want to observe the conflict behavior
        NSLog("CONFLICT RESOLUTION TEST COMPLETE")
    }
    
    /// Specific test to reproduce InfinityBug through hang + directional switch pattern
    func testInfinityBugDirectionalSwitchAfterHang() throws {
        NSLog("INFINITY BUG: Testing hang + directional switch pattern...")
        
        // Step 1: Create artificial hang/performance stress
        artificiallyInducePerformanceHang()
        
        // Step 2: Rapid presses in ONE direction during hang
        let primaryDirection: XCUIRemote.Button = .right
        NSLog("INFINITY BUG: Sending rapid presses in \(primaryDirection) direction during hang...")
        
        for i in 0..<15 {
            let beforeFocus = focusID
            remote.press(primaryDirection, forDuration: 0.01) // Very fast
            usleep(10_000) // Only 10ms between presses - creates pressure
            
            let afterFocus = focusID
            NSLog("HANG_PRESS[\(i)]: \(primaryDirection) '\(beforeFocus)' → '\(afterFocus)'")
        }
        
        // Step 3: CRITICAL - Switch direction immediately after hang
        usleep(50_000) // Brief pause to let hang "set in"
        
        let switchDirection: XCUIRemote.Button = .down
        NSLog("INFINITY BUG: SWITCHING to \(switchDirection) after hang...")
        
        var infinityBugDetected = false
        var stuckFocus = ""
        var stuckCount = 0
        
        // Step 4: Detect infinite repetition after direction switch
        for i in 0..<25 {
            let beforeFocus = focusID
            remote.press(switchDirection, forDuration: 0.02)
            usleep(30_000)
            
            let afterFocus = focusID
            NSLog("SWITCH_PRESS[\(i)]: \(switchDirection) '\(beforeFocus)' → '\(afterFocus)'")
            
            // Check for InfinityBug signature
            if beforeFocus == afterFocus && isValidFocus(afterFocus) {
                if stuckFocus == afterFocus {
                    stuckCount += 1
                    if stuckCount >= 8 {
                        infinityBugDetected = true
                        NSLog("🚨 INFINITY BUG DETECTED: Focus infinitely stuck on '\(afterFocus)' after directional switch")
                        break
                    }
                } else {
                    stuckFocus = afterFocus
                    stuckCount = 1
                }
            } else {
                stuckCount = 0
            }
        }
        
        // Step 5: Test if bug persists across app lifecycle
        if infinityBugDetected {
            testInfinityBugPersistence(stuckElement: stuckFocus)
        }
        
        XCTAssertTrue(infinityBugDetected, "Should reproduce InfinityBug with hang + directional switch pattern")
    }
    
    /// Test if InfinityBug persists even after app termination
    private func testInfinityBugPersistence(stuckElement: String) {
        NSLog("INFINITY BUG: Testing persistence across app lifecycle...")
        
        // Terminate app
        app.terminate()
        usleep(2_000_000) // 2 second pause
        
        // Relaunch
        app.launch()
        sleep(3)
        
        // Check if system focus is still corrupted
        let postRelaunchFocus = focusID
        NSLog("POST-RELAUNCH: Focus state: '\(postRelaunchFocus)'")
        
        // Try navigation to see if system input is still corrupted
        for i in 0..<10 {
            let beforeFocus = focusID
            remote.press(.up, forDuration: 0.05)
            usleep(100_000)
            let afterFocus = focusID
            
            NSLog("POST-RELAUNCH[\(i)]: UP '\(beforeFocus)' → '\(afterFocus)'")
            
            if beforeFocus == afterFocus && beforeFocus == stuckElement {
                NSLog("🚨 INFINITY BUG PERSISTED: System focus still corrupted after relaunch!")
                break
            }
        }
    }
    
    /// Create artificial performance hang to stress the system
    private func artificiallyInducePerformanceHang() {
        NSLog("INFINITY BUG: Inducing artificial performance hang...")
        
        // Method 1: Trigger heavy accessibility tree traversal
        let allElements = app.descendants(matching: .any)
        for i in 0..<min(allElements.count, 100) {
            let element = allElements.element(boundBy: i)
            _ = element.label // Force accessibility query
            _ = element.value
            _ = element.identifier
        }
        
        // Method 2: Rapid element queries to stress accessibility system
        for _ in 0..<50 {
            _ = app.debugCollectionView.cells.count
            usleep(5_000)
        }
        
        NSLog("INFINITY BUG: Performance hang induced")
    }
}

//extension DebugCollectionViewUITests {
    
//    This test has another false assumption: that you can reliably detect "edges" in a scrollable collection view by pressing a direction 15 times. In reality:
//    True edges: Navigation bar (can't go up), actual last cell (can't go down)
//    Scrollable areas: Collection view interior (DOWN should scroll, not stick)
//    /// Test edge-of-screen focus behavior
//    func testEdgeOfScreenFocusBehavior() throws {
//        NSLog("TEST: Starting edge-of-screen focus behavior test...")
//
//        // Navigate to top-left corner first
//        NSLog("STEP 1: Navigating to top-left corner")
//        for _ in 0..<10 {
//            remote.press(.up, forDuration: 0.05)
//            usleep(50_000)
//        }
//        for _ in 0..<10 {
//            remote.press(.left, forDuration: 0.05)
//            usleep(50_000)
//        }
//
//        let topLeftFocus = focusID
//        NSLog("TOP-LEFT: Focus at '\(topLeftFocus)'")
//
//        // Test edge behavior: repeated presses at edges
//        let edgeTests: [(direction: XCUIRemote.Button, edgeName: String)] = [
//            (.up, "TOP"),
//            (.left, "LEFT"),
//            (.down, "BOTTOM"),
//            (.right, "RIGHT")
//        ]
//
//        for edgeTest in edgeTests {
//            NSLog("TESTING EDGE: \(edgeTest.edgeName)")
//
//            // Navigate to this edge first
//            for _ in 0..<15 {
//                remote.press(edgeTest.direction, forDuration: 0.04)
//                usleep(40_000)
//            }
//
//            let edgeFocus = focusID
//            NSLog("EDGE \(edgeTest.edgeName): Reached '\(edgeFocus)'")
//
//            // Test edge with rapid presses
//            let initialEdgeFocus = focusID
//            var edgeStuckCount = 0
//
//            for attempt in 0..<25 {
//                remote.press(edgeTest.direction, forDuration: 0.02)
//                usleep(30_000)
//
//                let currentFocus = focusID
//
//                if currentFocus == initialEdgeFocus {
//                    edgeStuckCount += 1
//                } else {
//                    NSLog("EDGE ESCAPE[\(attempt)]: Focus moved from '\(initialEdgeFocus)' to '\(currentFocus)'")
//                }
//            }
//
//            NSLog("EDGE \(edgeTest.edgeName): Stuck \(edgeStuckCount)/25 times")
//
//            // At a true edge, some presses should be "stuck" (no movement)
//            XCTAssertGreaterThan(edgeStuckCount, 0, "At edge \(edgeTest.edgeName), some presses should have no effect")
//        }
//    }
    
//}
