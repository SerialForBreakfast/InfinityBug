//
//  ViewController.swift
//  HammerTime
//
//  Created by Joseph McCraw on 6/13/25.
//
//  This is designed with a complex heirarchy and conflicts indended to reproduce the InfinityBug

import UIKit

class ViewController: UIViewController {

    private var sampleViewController: SampleViewController?
    /// Top navigation bar controller (6‑item horizontal menu)
    private var navBarViewController: NavBarViewController?
    
    // INFINITY BUG ENHANCEMENT: Add performance stress elements
    private var heavyAnimationTimer: Timer?
    private var accessibilityStressViews: [UIView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gray
        // Do any additional setup after loading the view.
        // ─── Setup top navigation bar ──────────────────────────────────────────────
        let navVC: NavBarViewController = NavBarViewController()
        navBarViewController = navVC            // Store reference
        addChild(navVC)
        view.addSubview(navVC.view)
        navVC.didMove(toParent: self)
        navVC.view.translatesAutoresizingMaskIntoConstraints = false

        let sampleVC = SampleViewController()
        
        // Use ContainerFactory to wrap the sample view controller
        let wrappedSampleVC = ContainerFactory.wrap(sampleVC)
        sampleViewController = sampleVC // Store reference to original for access
        
        addChild(wrappedSampleVC)
        view.addSubview(wrappedSampleVC.view)
        wrappedSampleVC.didMove(toParent: self)
        
        wrappedSampleVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // Nav bar (edge‑to‑edge across top)
            navVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navVC.view.heightAnchor.constraint(equalToConstant: 120),

            // Wrapped sample grid below nav bar
            wrappedSampleVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wrappedSampleVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wrappedSampleVC.view.topAnchor.constraint(equalTo: navVC.view.bottomAnchor),
            wrappedSampleVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        // Ensure nav bar is above sample grid & any debug overlays
        view.bringSubviewToFront(navVC.view)
        NSLog("APP DEBUG: NavBar brought to front (z = \(navVC.view.layer.zPosition))")
        NSLog("APP: ViewController loaded with ContainerFactory wrapping")
        
        // INFINITY BUG ENHANCEMENTS:
        addAccessibilityStressElements()
        startPerformanceStressors()
        addFocusConflictElements()
        setupAccessibilityObservers()
    }
    
    /// Add elements that create accessibility tree traversal stress
    private func addAccessibilityStressElements() {
        NSLog("INFINITY BUG: Adding accessibility stress elements...")
        
        // Create 100 invisible but accessible elements
        for i in 0..<100 {
            let stressView = UIView()
            stressView.isHidden = true
            stressView.isAccessibilityElement = true
            stressView.accessibilityIdentifier = "Stress-\(i)"
            stressView.accessibilityLabel = "Stress element \(i) with very long description that forces VoiceOver to work harder during tree traversal and focus calculations"
            
            view.addSubview(stressView)
            accessibilityStressViews.append(stressView)
        }
        
        // Create competing accessibility containers
        for i in 0..<10 {
            let container = UIView()
            container.isAccessibilityElement = false
            container.accessibilityIdentifier = "StressContainer-\(i)"
            
            // Point to same collection view - creates conflicts
            if let collectionView = sampleViewController?.debugCollectionView {
                container.accessibilityElements = [collectionView]
            }
            
            view.addSubview(container)
        }
    }
    
    /// Start continuous performance stressors
    private func startPerformanceStressors() {
        NSLog("INFINITY BUG: Starting performance stressors...")
        
        // Heavy animation that interferes with focus calculations
        heavyAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            // Continuous layout changes during navigation
            for stressView in self.accessibilityStressViews {
                stressView.transform = CGAffineTransform(rotationAngle: CGFloat.random(in: 0...2*Double.pi))
            }
            
            // Force accessibility notifications
            if Int.random(in: 0...100) < 5 { // 5% chance
                UIAccessibility.post(notification: .layoutChanged, argument: nil)
            }
        }
    }
    
    /// Add elements that create focus conflicts
    private func addFocusConflictElements() {
        NSLog("INFINITY BUG: Adding focus conflict elements...")
        
        // Create focus guides that compete with natural focus flow
        for i in 0..<20 {
            let conflictGuide = UIFocusGuide()
            conflictGuide.preferredFocusEnvironments = [view] // Circular reference
            view.addLayoutGuide(conflictGuide)
            
            // Tiny frame that's hard to escape
            conflictGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(i * 10)).isActive = true
            conflictGuide.topAnchor.constraint(equalTo: view.topAnchor, constant: CGFloat(i * 5)).isActive = true
            conflictGuide.widthAnchor.constraint(equalToConstant: 1).isActive = true
            conflictGuide.heightAnchor.constraint(equalToConstant: 1).isActive = true
        }
    }
    
    /// Monitor for InfinityBug conditions
    private func setupAccessibilityObservers() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.elementFocusedNotification,
            object: nil,
            queue: .main
        ) { notification in
            // Log when VoiceOver focus moves
            let focusInfo = notification.userInfo
            NSLog("INFINITY BUG MONITOR: VoiceOver focus changed: \(String(describing: focusInfo))")
            
            // Detect focus/performance divergence
            self.detectFocusPerformanceDivergence()
        }
    }
    
    /// Detect when VoiceOver focus diverges from expected performance
    private func detectFocusPerformanceDivergence() {
        // Measure accessibility tree traversal time
        let startTime = CACurrentMediaTime()
        
        let _ = view.accessibilityElements // Force traversal
        
        let traversalTime = CACurrentMediaTime() - startTime
        
        if traversalTime > 0.1 { // >100ms indicates stress
            NSLog("CRITICAL: INFINITY BUG CONDITION: Accessibility traversal taking \(traversalTime)s - InfinityBug likely")
        }
    }
    
    deinit {
        heavyAnimationTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}


import UIKit

final class SampleViewController: UIViewController {
    
    private let dataSourceCount: Int = 100
    private lazy var cv: DebugCollectionView = {
        // Simple flow for clarity – swap to compositional if needed.
        let layout: UICollectionViewFlowLayout = {
            let l = UICollectionViewFlowLayout()
            l.itemSize                   = .init(width: 350, height: 200)
            l.minimumInteritemSpacing    = 40
            l.minimumLineSpacing         = 60
            l.scrollDirection            = .vertical
            return l
        }()
        
        let cView = DebugCollectionView(frame: .zero,
                                        collectionViewLayout: layout)
        cView.translatesAutoresizingMaskIntoConstraints = false
        cView.accessibilityIdentifier = "DebugCollectionView"
        cView.isPrefetchingEnabled    = false           // deterministic tests
        cView.backgroundColor         = .black
        cView.dataSource              = self
        cView.delegate                = self
        cView.register(DebugCell.self,
                       forCellWithReuseIdentifier: DebugCell.reuseID)
        return cView
    }()
    
    // Public accessor for the collection view
    public var debugCollectionView: DebugCollectionView {
        return cv
    }
    
    override func viewDidLoad() {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black   // match root background
        super.viewDidLoad()
        view.addSubview(cv)
        NSLayoutConstraint.activate([
            cv.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cv.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cv.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            cv.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }
}

extension SampleViewController: UICollectionViewDataSource,
                                UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        dataSourceCount
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DebugCell.reuseID,
            for: indexPath) as! DebugCell
        cell.configure(index: indexPath.item)
        return cell
    }
}


//
//  DebugCell.swift
//

import UIKit

final class DebugCell: UICollectionViewCell {
    static let reuseID = "DebugCell"
    
    private let label: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font      = .monospacedSystemFont(ofSize: 36, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        return l
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(label)
        contentView.backgroundColor = .systemBlue
        contentView.layer.cornerRadius = 12
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(index: Int) {
        label.text = "\(index)"
        accessibilityIdentifier = "Cell-\(index)"
        isAccessibilityElement  = true
        accessibilityLabel      = "Item number \(index)"
        accessibilityValue     = "Collection cell"
        accessibilityHint      = "Navigatable item in collection"
        accessibilityTraits   = [.button, .updatesFrequently]
    }
    
    // MARK: - Focus Handling
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                // Cell is now focused - change to green
                self.contentView.backgroundColor = .systemGreen
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1) // Optional: slight scale up
                
                // Announce focus change for VoiceOver testing
                if ProcessInfo.processInfo.environment["ACCESSIBILITY_TESTING"] == "1" {
                    let announcement = "Focused on \(self.accessibilityLabel ?? "item")"
                    UIAccessibility.post(notification: .announcement, argument: announcement)
                    NSLog("CELL: Posted focus announcement: '\(announcement)'")
                }
            } else {
                // Cell is no longer focused - change back to blue
                self.contentView.backgroundColor = .systemBlue
                self.transform = .identity // Reset scale
            }
        }, completion: nil)
    }
}


//
//  DebugCollectionView.swift
//  InfinityBugDiagnostics
//
//  Created by <Your Name> on 2025-06-13.
//  Copyright © 2025.
//
//  A UICollectionView subclass that logs                   ───────────────
//  • Every tvOS-remote press (pressesBegan / pressesEnded)
//  • Every focus transfer (didUpdateFocus)
//  • VoiceOver start/stop & per-element focus changes
//  • Detects "Read Screen After Delay" sweeps (rapid VO focus cycling)
//  • Optional debounce gate to suppress runaway press storms
//


// MARK: -- Log Models -------------------------------------------------------

public struct DebugLogEntry {
    public let timestamp: Date
    public let category: Category
    public let details: String
    
    public enum Category: String {
        case focus          = "FOCUS"
        case remotePress    = "PRESS"
        case accessibility  = "AX"
        case system         = "SYS"
    }
}

public final class DebugCollectionView: UICollectionView {
    
    // MARK: -- Public configuration ----------------------------------------
    
    /// Enable / disable console printing without recompiling
    public var isLoggingEnabled: Bool = true
    
    /// The shared detector instance for analyzing InfinityBug conditions.
    public let bugDetector = InfinityBugDetector()
    
    /// Enable / disable debounce strategy for VoiceOver
    public var debouncePressesEnabled: Bool = true
    
    /// Minimum interval (s) between accepted remote presses when debouncing
    public var debounceInterval: TimeInterval = 0.20
    
    /// Publicly accessible log for unit / UI testing
    public private(set) var eventLog: [DebugLogEntry] = []
    
    // MARK: -- Debug UI for Testing ----------------------------------------
    
    private lazy var debugLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityIdentifier = "DebugLogCountLabel"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.isHidden = !isDebugMode
        return label
    }()
    
    private var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: -- Private state -----------------------------------------------
    
    private var lastPressTimestamp: TimeInterval = 0.0
    private var lastFocusedIdentifier: String?
    private var consecutiveIdenticalFocuses: Int = 0
    private let focusRepeatThreshold: Int = 30        // InfinityBug heuristic
    
    // MARK: -- Lifecycle ----------------------------------------------------
    
    public override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        self.accessibilityIdentifier = "DebugCollectionView"
        commonInit()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.accessibilityIdentifier = "DebugCollectionView"
        commonInit()
    }
    
    private func commonInit() {
        // Observe all available UIAccessibility notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil)
        
        // Switch Control state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwitchControlStatusChanged),
            name: UIAccessibility.switchControlStatusDidChangeNotification,
            object: nil)
        
        // Assistive Touch state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAssistiveTouchStatusChanged),
            name: UIAccessibility.assistiveTouchStatusDidChangeNotification,
            object: nil)
        
        // Reduce Motion state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReduceMotionStatusChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil)
        
        // Reduce Transparency state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReduceTransparencyStatusChanged),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil)
        
        // Invert Colors state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInvertColorsStatusChanged),
            name: UIAccessibility.invertColorsStatusDidChangeNotification,
            object: nil)
        
        // Closed Captioning state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClosedCaptioningStatusChanged),
            name: UIAccessibility.closedCaptioningStatusDidChangeNotification,
            object: nil)
        
        // Bold Text state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBoldTextStatusChanged),
            name: UIAccessibility.boldTextStatusDidChangeNotification,
            object: nil)
        
        // Button Shapes state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleButtonShapesStatusChanged),
            name: UIAccessibility.buttonShapesEnabledStatusDidChangeNotification,
            object: nil)
        
        // Grayscale state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGrayscaleStatusChanged),
            name: UIAccessibility.grayscaleStatusDidChangeNotification,
            object: nil)
        
        // Guided Access state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGuidedAccessStatusChanged),
            name: UIAccessibility.guidedAccessStatusDidChangeNotification,
            object: nil)
        
        // Mono Audio state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMonoAudioStatusChanged),
            name: UIAccessibility.monoAudioStatusDidChangeNotification,
            object: nil)
        
        // Shake to Undo state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShakeToUndoStatusChanged),
            name: UIAccessibility.shakeToUndoDidChangeNotification,
            object: nil)
        
        // Speak Screen state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSpeakScreenStatusChanged),
            name: UIAccessibility.speakScreenStatusDidChangeNotification,
            object: nil)
        
        // Speak Selection state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSpeakSelectionStatusChanged),
            name: UIAccessibility.speakSelectionStatusDidChangeNotification,
            object: nil)
        
        // Announcement finished notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAnnouncementFinished(_:)),
            name: UIAccessibility.announcementDidFinishNotification,
            object: nil)
        
        // Note: Focus tracking is handled by didUpdateFocus method instead of notifications
        
        // Add debug label for UI testing
        setupDebugLabel()
        
        // Reset the detector if requested by a launch argument from the UI test.
        if ProcessInfo.processInfo.arguments.contains("-ResetBugDetector") {
            Task {
                await bugDetector.reset()
                log(category: .system, "InfinityBugDetector has been reset for new test run.")
            }
        }
        
//        AXFocusDebugger.shared.start()
    }
    
    private func setupDebugLabel() {
        guard isDebugMode else { return }
        
        addSubview(debugLabel)
        NSLayoutConstraint.activate([
            debugLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            debugLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            debugLabel.widthAnchor.constraint(equalToConstant: 80),
            debugLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        updateDebugLabel()
    }
    
    private func updateDebugLabel() {
        guard isDebugMode else { return }
        
        let pressCount = eventLog.filter { $0.category == .remotePress }.count
        debugLabel.text = "\(pressCount)"
        debugLabel.accessibilityLabel = "Debug log count: \(pressCount)"
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: -- Focus Tracking ----------------------------------------------
    
    /// Called whenever tvOS moves focus to / from this collection view        [oai_citation:1‡developer.apple.com](https://developer.apple.com/documentation/uikit/uicollectionviewdelegate/collectionview%28_%3Adidupdatefocusin%3Awith%3A%29?language=objc&utm_source=chatgpt.com)
    public override func didUpdateFocus(
        in context: UIFocusUpdateContext,
        with coordinator: UIFocusAnimationCoordinator)
    {
        super.didUpdateFocus(in: context, with: coordinator)
        
        guard let next = context.nextFocusedItem else { return }
        let identifier: String
        if let view = next as? UIView {
            identifier = view.accessibilityIdentifier ?? "<Unnamed>"
        } else if let element = next as? UIAccessibilityElement {
            identifier = element.accessibilityIdentifier ?? "<Unnamed>"
        } else {
            identifier = "<Unnamed>"
        }
        
        // Feed the detector with the focus event
        Task { await bugDetector.processEvent(type: .focus, identifier: identifier) }
        
        log(category: .focus,
            "Focus moved from \(String(describing: context.previouslyFocusedItem)) " +
            "→ \(identifier)")
        
        // InfinityBug early warning: same element reported too many times
        if identifier == lastFocusedIdentifier {
            consecutiveIdenticalFocuses += 1
            if consecutiveIdenticalFocuses >= focusRepeatThreshold {
                log(category: .system,
                    "WARNING: Potential InfinityBug - focus stuck on \(identifier) " +
                    "(\(consecutiveIdenticalFocuses) repeats)")
            }
        } else {
            consecutiveIdenticalFocuses = 0
            lastFocusedIdentifier = identifier
        }
    }
    
    // MARK: -- Remote-button Logging & Debounce ----------------------------
    
    public override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Feed the detector with the press event
        for press in presses {
            Task { await bugDetector.processEvent(type: .press(press.type), identifier: self.lastFocusedIdentifier) }
        }
        
        let now: TimeInterval = CACurrentMediaTime()
        
        if debouncePressesEnabled,
           now - lastPressTimestamp < debounceInterval,
           UIAccessibility.isVoiceOverRunning {
            // Drop the press; log & return without calling super
            log(category: .remotePress,
                "DEBOUNCED: \(presses.map { $0.type.debugName }.joined(separator: ","))")
            return
        }
        
        lastPressTimestamp = now
        log(category: .remotePress,
            "PRESS_BEGIN: \(presses.map { $0.type.debugName }.joined(separator: ",")) began")
        
        super.pressesBegan(presses, with: event)
    }
    
    public override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        log(category: .remotePress,
            "PRESS_END: \(presses.map { $0.type.debugName }.joined(separator: ",")) ended")
        super.pressesEnded(presses, with: event)
    }
    
    // MARK: -- VoiceOver Notifications -------------------------------------
    
    @objc private func handleVoiceOverStatusChanged() {
        let running: Bool = UIAccessibility.isVoiceOverRunning
        log(category: .accessibility,
            running ? "VoiceOver ENABLED" : "VoiceOver DISABLED")
        
        // Reset debounce whenever VO toggles
        lastPressTimestamp = 0
    }
    
    @objc private func handleSwitchControlStatusChanged() {
        let enabled: Bool = UIAccessibility.isSwitchControlRunning
        log(category: .accessibility,
            enabled ? "Switch Control ENABLED" : "Switch Control DISABLED")
    }
    
    @objc private func handleAssistiveTouchStatusChanged() {
        let enabled: Bool = UIAccessibility.isAssistiveTouchRunning
        log(category: .accessibility,
            enabled ? "AssistiveTouch ENABLED" : "AssistiveTouch DISABLED")
    }
    
    @objc private func handleReduceMotionStatusChanged() {
        let enabled: Bool = UIAccessibility.isReduceMotionEnabled
        log(category: .accessibility,
            enabled ? "Reduce Motion ENABLED" : "Reduce Motion DISABLED")
    }
    
    @objc private func handleReduceTransparencyStatusChanged() {
        let enabled: Bool = UIAccessibility.isReduceTransparencyEnabled
        log(category: .accessibility,
            enabled ? "Reduce Transparency ENABLED" : "Reduce Transparency DISABLED")
    }
    
    @objc private func handleInvertColorsStatusChanged() {
        let enabled: Bool = UIAccessibility.isInvertColorsEnabled
        log(category: .accessibility,
            enabled ? "Invert Colors ENABLED" : "Invert Colors DISABLED")
    }
    
    @objc private func handleClosedCaptioningStatusChanged() {
        let enabled: Bool = UIAccessibility.isClosedCaptioningEnabled
        log(category: .accessibility,
            enabled ? "Closed Captioning ENABLED" : "Closed Captioning DISABLED")
    }
    
    @objc private func handleBoldTextStatusChanged() {
        let enabled: Bool = UIAccessibility.isBoldTextEnabled
        log(category: .accessibility,
            enabled ? "Bold Text ENABLED" : "Bold Text DISABLED")
    }
    
    @objc private func handleButtonShapesStatusChanged() {
        let enabled: Bool = UIAccessibility.buttonShapesEnabled
        log(category: .accessibility,
            enabled ? "Button Shapes ENABLED" : "Button Shapes DISABLED")
    }
    
    @objc private func handleGrayscaleStatusChanged() {
        let enabled: Bool = UIAccessibility.isGrayscaleEnabled
        log(category: .accessibility,
            enabled ? "Grayscale ENABLED" : "Grayscale DISABLED")
    }
    
    @objc private func handleGuidedAccessStatusChanged() {
        let enabled: Bool = UIAccessibility.isGuidedAccessEnabled
        log(category: .accessibility,
            enabled ? "Guided Access ENABLED" : "Guided Access DISABLED")
    }
    
    @objc private func handleMonoAudioStatusChanged() {
        let enabled: Bool = UIAccessibility.isMonoAudioEnabled
        log(category: .accessibility,
            enabled ? "Mono Audio ENABLED" : "Mono Audio DISABLED")
    }
    
    @objc private func handleShakeToUndoStatusChanged() {
        let enabled: Bool = UIAccessibility.isShakeToUndoEnabled
        log(category: .accessibility,
            enabled ? "Shake to Undo ENABLED" : "Shake to Undo DISABLED")
    }
    
    @objc private func handleSpeakScreenStatusChanged() {
        let enabled: Bool = UIAccessibility.isSpeakScreenEnabled
        log(category: .accessibility,
            enabled ? "Speak Screen ENABLED" : "Speak Screen DISABLED")
    }
    
    @objc private func handleSpeakSelectionStatusChanged() {
        let enabled: Bool = UIAccessibility.isSpeakSelectionEnabled
        log(category: .accessibility,
            enabled ? "Speak Selection ENABLED" : "Speak Selection DISABLED")
    }
    
    @objc private func handleAnnouncementFinished(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let announcement = userInfo[UIAccessibility.announcementStringValueUserInfoKey] as? String,
           let wasSuccessful = userInfo[UIAccessibility.announcementWasSuccessfulUserInfoKey] as? Bool {
            log(category: .accessibility,
                "VOICEOVER: Announcement: '\(announcement)' - Success: \(wasSuccessful)")
        } else {
            log(category: .accessibility, "VOICEOVER: Announcement finished (no details)")
        }
    }
    
    
    // MARK: -- Read Screen After Delay Detection ---------------------------
    //
    // VoiceOver's two-finger-swipe-up triggers a rapid automatic traversal.
    // We detect that burst by measuring > 15 focus moves in under 2 seconds.
    //
    
    private var readSweepStart: Date = .distantPast
    private var readSweepFocusCount: Int = 0
    
    private func recordReadSweepSamples() {
        let now: Date = .init()
        if now.timeIntervalSince(readSweepStart) > 2.0 {
            // Reset the window
            readSweepStart = now
            readSweepFocusCount = 0
        }
        readSweepFocusCount += 1
        
        if readSweepFocusCount == 15 {
            log(category: .accessibility,
                "DETECTED: VoiceOver 'Read Screen After Delay' sweep")
        }
    }
    
    // Injected from didUpdateFocus
    private func logReadSweepSample() { recordReadSweepSamples() }
    
    // MARK: -- Logging Helper ----------------------------------------------
    
    private func log(category: DebugLogEntry.Category, _ message: @autoclosure () -> String) {
        let entry: DebugLogEntry = .init(timestamp: Date(),
                                         category: category,
                                         details: message())
        eventLog.append(entry)
        
        if isLoggingEnabled {
            let dateString: String = ISO8601DateFormatter().string(from: entry.timestamp)
            NSLog("[\(entry.category.rawValue)] \(dateString) – \(entry.details)")
        }
        
        // Feed VO read-sweep detector with focus samples
        if category == .focus { logReadSweepSample() }
        
        // Update debug label for UI testing
        updateDebugLabel()
    }
    
    // MARK: -- Test Utilities ----------------------------------------------
    
    /// Clears the in-memory event log (useful between XCTest methods).
    public func resetLog() { eventLog.removeAll() }
    
    /// Post a test announcement to verify VoiceOver is working
    /// NOTE: This only works if VoiceOver is already enabled in Settings
    public static func testVoiceOverAnnouncement() {
        let testMessage = "VoiceOver test announcement - if you hear this, VoiceOver is working"
        UIAccessibility.post(notification: .announcement, argument: testMessage)
        NSLog("VOICEOVER: Posted test announcement: '\(testMessage)'")
    }
    
    /// Enable enhanced VoiceOver logging for testing
    /// NOTE: This assumes VoiceOver is already enabled in Settings
    public func enableVoiceOverTestMode() {
        log(category: .accessibility, "TEST: VoiceOver test mode enabled")
        
        // Post a test announcement (only works if VoiceOver is already on)
        DebugCollectionView.testVoiceOverAnnouncement()
        
        // Log current VoiceOver state
        let voiceOverRunning = UIAccessibility.isVoiceOverRunning
        log(category: .accessibility, "VOICEOVER: VoiceOver running: \(voiceOverRunning)")
        
        if voiceOverRunning {
            log(category: .accessibility, "SUCCESS: VoiceOver is active and should be narrating elements")
        } else {
            log(category: .accessibility, "INFO: VoiceOver not detected - enable it in Settings for audio narration")
        }
    }
}

// MARK: -- UIPressType Convenience ------------------------------------------

private extension UIPress.PressType {
    var debugName: String {
        switch self {
        case .upArrow:            return "UP"
        case .downArrow:          return "DOWN"
        case .leftArrow:          return "LEFT"
        case .rightArrow:         return "RIGHT"
        case .select:             return "SELECT"
        case .menu:               return "MENU"
        case .playPause:          return "PLAY_PAUSE"
        case .pageUp:             return "PAGE_UP"
        case .pageDown:           return "PAGE_DOWN"
        @unknown default:
            // Enhanced debugging for unknown press types
            switch rawValue {
            case 2080:               return "VOLUME_UP" // Volume Up (likely)
            case 2081:               return "VOLUME_DOWN" // Volume Down (likely)
            case 2230:               return "MUTE"  // Mute (likely)
            case 2240:               return "PREV_TRACK"  // Previous Track
            case 2241:               return "NEXT_TRACK"  // Next Track
            case 2250:               return "HOME"  // Home Button
            case 2260:               return "TV_BUTTON"  // TV Button
            case 2270:               return "GAME_CONTROLLER"  // Game Controller
            default:                 return "UNKNOWN_\(rawValue)[\(self.description)]"
            }
        }
    }
    
    var description: String {
        switch self {
        case .upArrow:            return "upArrow"
        case .downArrow:          return "downArrow"
        case .leftArrow:          return "leftArrow"
        case .rightArrow:         return "rightArrow"
        case .select:             return "select"
        case .menu:               return "menu"
        case .playPause:          return "playPause"
        case .pageUp:             return "pageUp"
        case .pageDown:           return "pageDown"
        @unknown default:         return "unknown(\(rawValue))"
        }
    }
}

// ============================================================================
// MARK: - NavBarCell
// ============================================================================

final class NavBarCell: UICollectionViewCell {
    static let reuseID: String = "NavBarCell"

    private let titleLabel: UILabel = {
        let l: UILabel = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .monospacedSystemFont(ofSize: 34, weight: .semibold)
        l.textColor = .white
        l.textAlignment = .center
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(titleLabel)
        contentView.backgroundColor = .systemGray
        contentView.layer.cornerRadius = 8

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with title: String) {
        titleLabel.text = title
        accessibilityIdentifier = "Nav-\(title)"
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = [.button]
    }

    // Focus feedback
    override func didUpdateFocus(in context: UIFocusUpdateContext,
                                 with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.contentView.backgroundColor = self.isFocused ? .systemGreen : .systemGray
            self.transform = self.isFocused ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
    }
}

// ============================================================================
// MARK: - NavBarViewController
// ============================================================================

final class NavBarViewController: UIViewController {

    private let titles: [String] = ["Header1", "Header2", "Header3",
                                    "Header4", "Header5", "Header6"]

    private lazy var collectionView: UICollectionView = {
        let layout: UICollectionViewFlowLayout = {
            let l: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
            l.scrollDirection = .horizontal
            l.itemSize = .init(width: 260, height: 80)
            l.minimumInteritemSpacing = 30
            l.minimumLineSpacing = 30
            return l
        }()
        let cv: UICollectionView = UICollectionView(frame: .zero,
                                                    collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.dataSource = self
        cv.delegate = self
        cv.remembersLastFocusedIndexPath = true
        cv.register(NavBarCell.self, forCellWithReuseIdentifier: NavBarCell.reuseID)
        return cv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .darkGray
        view.addSubview(collectionView)

        // Constrain collection view with insets for aesthetics
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])

        NSLog("NAVBAR: NavBarViewController loaded with \(titles.count) items")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NSLog("NAVBAR DEBUG: bar frame = \(view.frame)")
        NSLog("NAVBAR DEBUG: collection frame = \(collectionView.frame)")
        let cellFrames = collectionView.visibleCells.map { $0.frame }
        NSLog("NAVBAR DEBUG: visible cell frames = \(cellFrames)")
    }
}

// MARK: - UICollectionViewDataSource & Delegate
extension NavBarViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        titles.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: NavBarCell = collectionView.dequeueReusableCell(
            withReuseIdentifier: NavBarCell.reuseID,
            for: indexPath) as! NavBarCell
        let title: String = titles[indexPath.item]
        cell.configure(with: title)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        NSLog("NAVBAR: Selected \(titles[indexPath.item])")
    }
}
