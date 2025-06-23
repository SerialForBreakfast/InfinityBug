import XCTest

// MARK: - Navigation Strategy Framework

/// Defines the different navigation patterns for stress testing.
enum NavigationStrategy {
    case snake(direction: SnakeDirection)
    case spiral(direction: SpiralDirection)
    case diagonal(direction: DiagonalDirection)
    case cross(direction: CrossDirection)
    case edgeTest(edge: Edge)
    case randomWalk(seed: UInt64)
    
    enum SnakeDirection { case horizontal, vertical, bidirectional }
    enum SpiralDirection { case inward, outward }
    enum DiagonalDirection { case primary, secondary, cross }
    enum CrossDirection { case vertical, horizontal, full }
    enum Edge { case top, bottom, left, right, all }
}

/// Executes complex navigation strategies for focus stress testing.
/// OPTIMIZED: Zero focus queries during execution for maximum speed.
class NavigationStrategyExecutor {
    
    private let app: XCUIApplication
    private let remote: XCUIRemote
    
    init(app: XCUIApplication) {
        self.app = app
        self.remote = XCUIRemote.shared
    }
    
    /// Executes a given navigation strategy for a specified number of steps.
    /// CRITICAL: No focus queries during execution - pure button mashing for speed.
    func execute(_ strategy: NavigationStrategy, steps: Int) {
        NSLog("EXECUTOR: Starting \(steps) steps with ZERO focus queries for maximum speed")
        
        switch strategy {
        case .snake(let direction):
            executeSnake(direction: direction, steps: steps)
        case .spiral(let direction):
            executeSpiral(direction: direction, steps: steps)
        case .diagonal(let direction):
            executeDiagonal(direction: direction, steps: steps)
        case .cross(let direction):
            executeCross(direction: direction, steps: steps)
        case .edgeTest(let edge):
            executeEdgeTest(edge: edge, steps: steps)
        case .randomWalk(let seed):
            executeRandomWalk(seed: seed, steps: steps)
        }
        
        NSLog("EXECUTOR: Completed \(steps) rapid button presses")
    }
    
    // MARK: - Strategy Implementations (NO FOCUS QUERIES)
    
    /// Snake pattern: Rapid alternating directions - NO edge detection
    private func executeSnake(direction: NavigationStrategy.SnakeDirection, steps: Int) {
        NSLog("SNAKE: Rapid mashing for \(steps) steps, direction: \(direction)")
        
        let patterns: [[XCUIRemote.Button]] = [
            [.right, .right, .right, .down, .left, .left, .left, .down], // horizontal
            [.down, .down, .down, .right, .up, .up, .up, .right],       // vertical  
            [.right, .down, .left, .up, .right, .down, .left, .up]      // bidirectional
        ]
        
        let selectedPattern: [XCUIRemote.Button]
        switch direction {
        case .horizontal: selectedPattern = patterns[0]
        case .vertical: selectedPattern = patterns[1] 
        case .bidirectional: selectedPattern = patterns[2]
        }
        
        for step in 0..<steps {
            let buttonDirection = selectedPattern[step % selectedPattern.count]
            rapidPress(buttonDirection)
        }
    }
    
    /// Spiral pattern: Rapid expanding/contracting movement
    private func executeSpiral(direction: NavigationStrategy.SpiralDirection, steps: Int) {
        NSLog("SPIRAL: Rapid mashing for \(steps) steps, direction: \(direction)")
        
        let spiralPattern: [XCUIRemote.Button] = [.right, .down, .left, .up]
        var repeatCount = (direction == .outward) ? 1 : 3
        
        for step in 0..<steps {
            let patternIndex = (step / repeatCount) % spiralPattern.count
            let buttonDirection = spiralPattern[patternIndex]
            
            rapidPress(buttonDirection)
            
            // Adjust repeat count periodically
            if step % 16 == 0 {
                repeatCount = (direction == .outward) ? 
                    min(repeatCount + 1, 4) : max(repeatCount - 1, 1)
            }
        }
    }
    
    /// Diagonal pattern: Rapid diagonal movements
    private func executeDiagonal(direction: NavigationStrategy.DiagonalDirection, steps: Int) {
        NSLog("DIAGONAL: Rapid mashing for \(steps) steps, direction: \(direction)")
        
        let patterns: [[XCUIRemote.Button]] = [
            [.right, .down, .right, .down],           // primary
            [.left, .down, .left, .down],             // secondary
            [.right, .down, .left, .up, .right, .up, .left, .down] // cross
        ]
        
        let selectedPattern: [XCUIRemote.Button]
        switch direction {
        case .primary: selectedPattern = patterns[0]
        case .secondary: selectedPattern = patterns[1]
        case .cross: selectedPattern = patterns[2]
        }
        
        for step in 0..<steps {
            let buttonDirection = selectedPattern[step % selectedPattern.count]
            rapidPress(buttonDirection)
        }
    }
    
    /// Cross pattern: Rapid cross/plus movements
    private func executeCross(direction: NavigationStrategy.CrossDirection, steps: Int) {
        NSLog("CROSS: Rapid mashing for \(steps) steps, direction: \(direction)")
        
        let patterns: [[XCUIRemote.Button]] = [
            [.up, .up, .down, .down, .up, .down],           // vertical
            [.left, .left, .right, .right, .left, .right],  // horizontal
            [.up, .right, .down, .left, .up, .left, .down, .right] // full
        ]
        
        let selectedPattern: [XCUIRemote.Button]
        switch direction {
        case .vertical: selectedPattern = patterns[0]
        case .horizontal: selectedPattern = patterns[1]
        case .full: selectedPattern = patterns[2]
        }
        
        for step in 0..<steps {
            let buttonDirection = selectedPattern[step % selectedPattern.count]
            rapidPress(buttonDirection)
        }
    }
    
    /// Edge test: Rapid boundary testing - NO actual edge detection
    private func executeEdgeTest(edge: NavigationStrategy.Edge, steps: Int) {
        NSLog("EDGE-TEST: Rapid boundary mashing for \(steps) steps, edge: \(edge)")
        
        let edgePatterns: [[XCUIRemote.Button]] = [
            [.up, .up, .up, .right, .left],           // top
            [.down, .down, .down, .right, .left],     // bottom
            [.left, .left, .left, .up, .down],        // left
            [.right, .right, .right, .up, .down],     // right
            [.up, .right, .down, .left, .up, .left, .down, .right] // all
        ]
        
        let selectedPattern: [XCUIRemote.Button]
        switch edge {
        case .top: selectedPattern = edgePatterns[0]
        case .bottom: selectedPattern = edgePatterns[1]
        case .left: selectedPattern = edgePatterns[2]
        case .right: selectedPattern = edgePatterns[3]
        case .all: selectedPattern = edgePatterns[4]
        }
        
        for step in 0..<steps {
            let buttonDirection = selectedPattern[step % selectedPattern.count]
            rapidPress(buttonDirection)
        }
    }
    
    /// Random walk: Rapid pseudo-random navigation
    private func executeRandomWalk(seed: UInt64, steps: Int) {
        NSLog("RANDOM-WALK: Rapid mashing for \(steps) steps, seed: \(seed)")
        
        var rng = SeededRandomGenerator(seed: seed)
        let allDirections: [XCUIRemote.Button] = [.up, .down, .left, .right]
        
        for _ in 0..<steps {
            let randomDirection = allDirections[Int(rng.next()) % allDirections.count]
            rapidPress(randomDirection)
        }
    }
    
    // MARK: - Rapid Press Implementation
    
    /// Sends rapid directional press - NO focus queries, minimal timing
    /// Target: 100+ actions per minute (600ms per action maximum)
    private func rapidPress(_ direction: XCUIRemote.Button) {
        remote.press(direction, forDuration: 0.01)
        
        // Ultra-fast timing: 8ms to 200ms (much faster than before)
        let randomIntervalMicros = Int.random(in: 8_000...200_000)
        usleep(useconds_t(randomIntervalMicros))
    }
}

// MARK: - Seeded Random Number Generator

/// Simple seeded random number generator for reproducible random walks
struct SeededRandomGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        // Linear congruential generator
        state = state &* 1103515245 &+ 12345
        return state
    }
}

// MARK: - XCUIApplication Helper

extension XCUIApplication {
    /// Provides a safe accessor for the currently focused element.
    /// Uses hasFocus predicate instead of invalid KVC to avoid crashes.
    var focusedElement: XCUIElement {
        // Try to find any element that currently has focus
        let focusedElements = self.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true"))
        
        if focusedElements.count > 0 {
            return focusedElements.firstMatch
        }
        
        // Fallback: return the collection view itself for frame calculations
        let collectionView = self.collectionViews["FocusStressCollectionView"]
        if collectionView.exists {
            return collectionView
        }
        
        // Last resort: return the application itself
        return self
    }
} 