//  ConstraintThrashManager.swift
//  HammerTime
//
//  Generates incremental Auto Layout load by continually adding solvable constraints to
//  an off-screen view.  Each batch increases the total constraint count, forcing the
//  layout engine to solve ever-larger systems – a near-linear cost surface that helps
//  surface RunLoop stalls and, ultimately, InfinityBug.
//
//  Enabled with launch argument "-ConstraintThrash YES" (default batchSize = 4) or env
//  vars CONSTRAINT_THRASH=1, CONSTRAINT_THRASH_BATCHSIZE=6.
//
//  Concurrency: @MainActor – everything touches UIKit objects.

import UIKit
import CoreFoundation

@MainActor
final class ConstraintThrashManager {
    static let shared = ConstraintThrashManager()
    private init() {}

    // MARK: Private state
    private var thrashView: UIView?
    private var constraintCount: Int = 0
    private var batchSize: Int = 4

    func configureIfNeeded(from arguments: [String] = ProcessInfo.processInfo.arguments,
                           environment: [String:String] = ProcessInfo.processInfo.environment) {
        guard arguments.contains("-ConstraintThrash") || environment["CONSTRAINT_THRASH"] == "1" else { return }

        if let idx = arguments.firstIndex(of: "-ConstraintThrashBatchSize"), arguments.indices.contains(idx+1) {
            batchSize = Int(arguments[idx+1]) ?? batchSize
        }
        if let envSize = environment["CONSTRAINT_THRASH_BATCHSIZE"], let val = Int(envSize) { batchSize = val }

        setUpHiddenView()
        // Observe Darwin notification from UITests to add batch on demand
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center,
                                         nil,
                                         { _, _, _, _, _ in
                                            Task { @MainActor in
                                                ConstraintThrashManager.shared.addBatch()
                                            }
                                         },
                                         "com.showblender.hammertime.constraintThrash" as CFString,
                                         nil,
                                         .deliverImmediately)
        TestRunLogger.shared.log("🧩 ConstraintThrash enabled – batchSize: \(batchSize)")
    }

    /// Adds one batch of constraints; call as frequently as desired.
    func addBatch() {
        guard let view = thrashView else { return }
        let batch = createConstraintBatch(on: view)
        view.addConstraints(batch)
        constraintCount += batch.count
        TestRunLogger.shared.log("🧩 ConstraintThrash added \(batch.count) constraints (total: \(constraintCount))")
    }

    // MARK: Setup helpers
    private func setUpHiddenView() {
        let window = UIApplication.shared.windows.first ?? UIWindow(frame: .zero)
        let host = UIView(frame: .zero)
        host.isHidden = true
        window.addSubview(host)
        thrashView = host
    }

    /// Creates a solvable yet non-trivial set of constraints (≥6 vars).
    private func createConstraintBatch(on container: UIView) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []
        for _ in 0..<batchSize {
            let v1 = UIView()
            let v2 = UIView()
            v1.translatesAutoresizingMaskIntoConstraints = false
            v2.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(v1)
            container.addSubview(v2)

            constraints.append(contentsOf: [
                v1.widthAnchor.constraint(equalToConstant: 10),
                v1.heightAnchor.constraint(equalToConstant: 10),
                v2.widthAnchor.constraint(equalTo: v1.widthAnchor),
                v2.heightAnchor.constraint(equalTo: v1.heightAnchor),
                v2.leadingAnchor.constraint(equalTo: v1.trailingAnchor),
                v2.topAnchor.constraint(equalTo: v1.bottomAnchor)
            ])
        }
        return constraints
    }
} 