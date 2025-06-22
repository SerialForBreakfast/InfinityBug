//
//  InfinityBugDetector.swift
//  HammerTime
//
//  Created by Joseph McCraw on 6/19/25.
//
//  This actor provides a sophisticated, multi-heuristic system for detecting
//  the InfinityBug with high confidence, distinguishing true software loops
//  from legitimate rapid user input.
//

import Foundation
import UIKit

/// A notification posted when the detector reaches a high confidence score for the InfinityBug.
public extension Notification.Name {
    static let bugDetectedNotification = Notification.Name("com.infinitybug.highConfidenceDetection")
}

/// An actor-based system that uses a multi-heuristic approach to analyze focus and press
/// events, calculating a confidence score that the "InfinityBug" is occurring.
public actor InfinityBugDetector {
    
    // MARK: - Notifications
    
    /// Notification posted when the detector's confidence score exceeds the critical threshold.
    /// The `userInfo` dictionary contains detailed diagnostic information.
    static let bugDetectedNotification = Notification.Name("InfinityBugDetector.bugDetectedNotification")
    
    // MARK: - Public Properties
    
    /// A score from 0.0 to 1.0 indicating the confidence that an InfinityBug is occurring.
    private(set) var confidenceScore: Double = 0.0
    
    // MARK: - Private State
    
    private var eventHistory: [Event] = []
    private let maxHistory = 100 // Store the last 100 events
    private let criticalThreshold = 0.70
    private var hasFiredNotification = false

    /// Represents a single event (press or focus) with a timestamp.
    struct Event {
        enum EventType { case press(UIPress.PressType), focus }
        let type: EventType
        let identifier: String?
        let timestamp: TimeInterval
    }
    
    // MARK: - Public API
    
    /// Processes a new UI event and updates the InfinityBug confidence score.
    ///
    /// This is the main entry point for the detector. Call this for every press and focus
    /// event you want to analyze.
    /// - Parameters:
    ///   - type: The type of event that occurred.
    ///   - identifier: The accessibility identifier of the focused element, if available.
    func processEvent(type: Event.EventType, identifier: String?) {
        let now = CACurrentMediaTime()
        let event = Event(type: type, identifier: identifier, timestamp: now)
        
        // Add to history and trim
        eventHistory.append(event)
        if eventHistory.count > maxHistory {
            eventHistory.removeFirst()
        }
        
        // Recalculate confidence score based on the latest history
        recalculateConfidenceScore()
        
        // Fire notification if we cross the threshold for the first time
        if confidenceScore >= criticalThreshold && !hasFiredNotification {
            fireBugDetectedNotification()
            hasFiredNotification = true
        }
    }
    
    /// Resets the detector's state. Call this at the beginning of a new test case.
    func reset() {
        eventHistory.removeAll()
        confidenceScore = 0.0
        hasFiredNotification = false
    }
    
    // MARK: - Heuristic Calculations
    
    private func recalculateConfidenceScore() {
        // Run all heuristics and combine their scores.
        let frequencyScore = calculateFrequencyScore()
        let divergenceScore = calculateDivergenceScore()
        let cadenceScore = calculateCadenceScore()
        
        // Combine scores (weights can be tweaked)
        let totalScore = (frequencyScore * 0.5) + (divergenceScore * 0.3) + (cadenceScore * 0.2)
        
        // Decay the score over time if no new evidence appears
        let timeSinceLastEvent = (CACurrentMediaTime() - (eventHistory.last?.timestamp ?? 0))
        let decayFactor = 1.0 - min(1.0, timeSinceLastEvent / 2.0) // Decays over 2 seconds
        
        self.confidenceScore = totalScore * decayFactor
    }
    
    /// **Heuristic 1: The "Machine Gun" Detector**
    /// Calculates a score based on unnaturally fast input frequency.
    private func calculateFrequencyScore() -> Double {
        let pressEvents = eventHistory.filter { event in
            if case .press = event.type { return true }
            return false
        }
        
        guard pressEvents.count > 10 else { return 0.0 }
        
        let recentPresses = pressEvents.suffix(10)
        let deltas = zip(recentPresses, recentPresses.dropFirst()).map { $1.timestamp - $0.timestamp }
        
        // Count how many presses were faster than a human threshold (e.g., 25ms)
        let unnaturallyFastCount = deltas.filter { $0 < 0.025 }.count
        
        // Score is proportional to the number of "machine gun" presses.
        return Double(unnaturallyFastCount) / 10.0
    }
    
    /// **Heuristic 2: The "Black Hole" Detector**
    /// Calculates a score based on focus not changing despite directional input.
    private func calculateDivergenceScore() -> Double {
        guard eventHistory.count > 20 else { return 0.0 }
        
        let recentEvents = eventHistory.suffix(20)
        var directionalPresses = 0
        var focusChanges = 0
        
        var lastFocusIdentifier = recentEvents.first?.identifier
        
        for event in recentEvents {
            if case .press(let pressType) = event.type,
               [.upArrow, .downArrow, .leftArrow, .rightArrow].contains(pressType) {
                directionalPresses += 1
            }
            
            if case .focus = event.type {
                if event.identifier != lastFocusIdentifier {
                    focusChanges += 1
                    lastFocusIdentifier = event.identifier
                }
            }
        }
        
        // If there are many directional presses with very few focus changes, score is high.
        if directionalPresses > 10 {
            if focusChanges == 0 {
                return 1.0  // Perfect black hole
            } else if focusChanges <= 2 {
                return 0.8  // Near black hole - very limited focus movement
            } else if focusChanges <= 5 {
                return 0.6  // Moderate divergence - some focus movement but still problematic
            } else {
                // Calculate ratio-based score for cases with more changes
                let changeRatio = Double(focusChanges) / Double(directionalPresses)
                if changeRatio < 0.1 {  // Less than 10% change rate
                    return 0.4
                } else if changeRatio < 0.2 {  // Less than 20% change rate
                    return 0.2
                }
            }
        }
        
        return 0.0
    }
    
    /// **Heuristic 3: The "Metronome" Detector**
    /// Calculates a score based on the unnatural regularity of event timing.
    private func calculateCadenceScore() -> Double {
        let pressEvents = eventHistory.filter { event in
            if case .press = event.type { return true }
            return false
        }
        
        guard pressEvents.count > 15 else { return 0.0 }
        
        let recentPresses = pressEvents.suffix(15)
        let deltas = zip(recentPresses, recentPresses.dropFirst()).map { $1.timestamp - $0.timestamp }
        
        // Calculate the standard deviation of the time deltas.
        let mean = deltas.reduce(0, +) / Double(deltas.count)
        let variance = deltas.map { pow($0 - mean, 2) }.reduce(0, +) / Double(deltas.count)
        let stdDev = sqrt(variance)
        
        // A very low standard deviation (< 1ms) suggests a robotic, non-human cadence.
        if stdDev < 0.001 {
            return 1.0
        }
        
        // Score inversely proportional to standard deviation.
        return 1.0 - min(1.0, stdDev / 0.01) // Fully confident if std dev > 10ms
    }
    
    // MARK: - Notification Handling
    
    private func fireBugDetectedNotification() {
        let diagnostics = generateDiagnostics()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.bugDetectedNotification,
                object: nil,
                userInfo: ["diagnostics": diagnostics]
            )
        }
        
        NSLog("CRITICAL: InfinityBug Detected with confidence \(String(format: "%.2f", confidenceScore)). Firing notification.")
    }
    
    /// Creates a dictionary of diagnostic information to include in the notification.
    private func generateDiagnostics() -> [String: Any] {
        return [
            "confidenceScore": confidenceScore,
            "triggeringHeuristics": [
                "frequencyScore": calculateFrequencyScore(),
                "divergenceScore": calculateDivergenceScore(),
                "cadenceScore": calculateCadenceScore()
            ],
            "eventHistoryTail": eventHistory.suffix(20).map {
                "\($0.timestamp): \(String(describing: $0.type)) on \($0.identifier ?? "nil")"
            }
        ]
    }
} 
