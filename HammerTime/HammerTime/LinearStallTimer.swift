//  LinearStallTimer.swift
//  HammerTime
//
//  Introduces a predictable, linearly growing main-thread stall for InfinityBug reproduction.
//  The timer fires every second; each tick blocks the main RunLoop by
//  (baseMillis + stepMillis × tick) milliseconds, producing a near-linear
//  latency curve.  Controlled via launch arguments / env variables so it
//  has zero impact on normal app runs.
//
//  Concurrency: @MainActor – all state lives on the main thread, ensuring
//  no data-race and that the stall truly impacts UI responsiveness.
//
//  Usage:
//  "-LinearStallMode YES"               – enable with defaults (20ms base, 15ms step)
//  "-LinearStallBaseMS 40"             – override base delay
//  "-LinearStallStepMS 25"             – override per-tick increment
//
//  © 2025 HammerTime Project

import Foundation
import QuartzCore
import UIKit

/// Linear, predictable RunLoop stalling mechanism for stress testing.
///
/// – Starts a 1 Hz `Timer` on the main RunLoop.
/// – On each tick `i` it sleeps the main thread for `base + step × i` ms.
/// – Produces a staircase latency graph (almost straight line when sampled).
/// – Designed solely for test instrumentation; **never** ship enabled.
@MainActor
final class LinearStallTimer {
    // MARK: Singleton
    static let shared = LinearStallTimer()
    private init() {}

    // MARK: Configuration
    private var baseMs: UInt32 = 20
    private var stepMs: UInt32 = 15

    // MARK: State
    private var tickCount: UInt32 = 0
    private var timer: Timer?

    /// Starts the timer with supplied parameters (or previously set ones).
    /// Calling `start` multiple times is a no-op.
    func start(baseMs: UInt32? = nil, stepMs: UInt32? = nil) {
        if let b = baseMs { self.baseMs = b }
        if let s = stepMs { self.stepMs = s }

        guard timer == nil else { return }

        TestRunLogger.shared.log("⏱ LinearStallTimer starting – base: \(self.baseMs) ms, step: \(self.stepMs) ms")

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.fire()
            }
        }
    }

    /// Invalidates the timer and resets counters.
    func stop() {
        timer?.invalidate()
        timer = nil
        tickCount = 0
        TestRunLogger.shared.log("⏱ LinearStallTimer stopped")
    }

    // MARK: Internal
    private func fire() {
        tickCount += 1
        let totalMs = baseMs + stepMs * tickCount

        // Break the delay into small slices so the RunLoop can keep spinning and
        // XCT remote events continue to queue – critical for reproducing the real
        // backlog that precedes InfinityBug.
        var remaining = totalMs
        let slice: UInt32 = 20 // ms – small enough to keep UI responsive, large enough to avoid thousands of iterations

        while remaining > 0 {
            let currentSlice = min(slice, remaining)
            usleep(currentSlice * 1_000) // ms → µs

            // Let the RunLoop process a bit of work (default mode)
            RunLoop.current.run(mode: .default, before: Date())
            remaining -= currentSlice
        }

        // AX query burst – forces extra work on the accessibility server, which
        // continues even while more remote events enter the queue, compounding
        // the chance of runaway focus.
        let axQueries = Int(max(1, tickCount / 2))
        for _ in 0..<axQueries {
            _ = UIAccessibility.focusedElement(using: nil)
        }

        TestRunLogger.shared.log("⏱ LinearStallTimer tick #\(tickCount) – cumulative stall \(totalMs) ms, AX queries: \(axQueries)")
    }
} 