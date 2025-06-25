//
//  FocusStressViewController.swift
//  HammerTime
//
//  Purpose: Reproduce the "InfinityBug" by combining multiple worst‑case
//  focus and accessibility stressors.  Excluded from RELEASE builds.
//
//  Enhanced stress patterns:
//  1. Nested layout structures (triple-nested groups)
//  2. Hidden/visible focusable traps scattered throughout cells
//  3. Jiggle timer (constant layout changes)
//  4. Circular focus guides (conflicting preferred environments)
//  5. Duplicate accessibility identifiers
//  6. Dynamic focus guides (rapidly changing preferred environments)
//  7. Rapid layout invalidation cycles
//  8. Overlapping invisible focusable elements
//  9. PROGRESSIVE STALL SYSTEM: Linear escalation to InfinityBug conditions
//  
//  Visual feedback: Focused cells turn blue with 1.05x scale
//

import UIKit
import SwiftUI

// MARK: - FocusStressViewController

/// DEBUG‑only VC that intentionally degrades focus performance for diagnostics.
final class FocusStressViewController: UIViewController {

    // MARK: Properties
    private var configuration: FocusStressConfiguration
    private var jiggleTimer: Timer?
    private var dynamicGuideTimer: Timer?
    private var layoutChangeTimer: Timer?
    /// Timer for posting random VoiceOver announcements to further stress the accessibility system.
    private var voAnnouncementTimer: Timer?
    /// Timer for creating memory pressure to stress the system for V6.0 reproduction tests
    private var memoryStressTimer: Timer?
    /// NEW: Progressive stress escalation timer for predictable InfinityBug reproduction
    private var progressiveStressTimer: Timer?
    private var focusGuides: [UIFocusGuide] = []
    /// Array of overlapping focus conflict elements for enhanced stress testing
    private var focusConflictElements: [UIView] = []
    
    // MARK: - Progressive Stress System Properties
    private var stressStartTime: TimeInterval = 0
    private var currentStressLevel: Int = 0
    private var memoryBallast: [[String]] = [] // Accumulated memory load
    private var voiceOverProcessingLoad: Int = 0 // Simulated VoiceOver overhead
    private var artificialStallDuration: TimeInterval = 0 // Programmatic stall injection

    private var collectionView: UICollectionView!
    
    private func createCollectionView() -> UICollectionView {
        let layout = UICollectionViewCompositionalLayout { [weak self] _, _ in
            guard let self = self else { return self?.makeSimpleSection() }
            switch self.configuration.layout.nestingLevel {
            case .simple:
                return self.makeSimpleSection()
            case .nested:
                return self.makeNestedSection()
            case .tripleNested:
                return self.makeTripleNestedSection()
            }
        }
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.remembersLastFocusedIndexPath = true
        cv.dataSource = self
        cv.delegate   = self
        cv.isPrefetchingEnabled = configuration.performance.prefetchingEnabled
        cv.accessibilityIdentifier = "FocusStressCollectionView"
        cv.register(StressCell.self, forCellWithReuseIdentifier: StressCell.reuseID)
        return cv
    }
    
    // MARK: Initializers
    
    init(configuration: FocusStressConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        // Load a default configuration from launch args, or a fallback with TRIPLE cells
        var config = FocusStressConfiguration.loadFromLaunchArguments()
        
        // Triple the navigation content for better edge-avoidance testing
        config.layout.numberOfSections = max(config.layout.numberOfSections * 3, 300) // Minimum 300 sections
        config.layout.itemsPerSection = max(config.layout.itemsPerSection * 3, 60)    // Minimum 60 items per section
        
        self.configuration = config
        super.init(coder: coder)
    }


    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // Start comprehensive logging for manual execution
        let isManualExecution = ProcessInfo.processInfo.environment["FOCUS_TEST_MODE"] != "1"
        if isManualExecution {
            // Determine preset from launch arguments
            let args = ProcessInfo.processInfo.arguments
            var presetName = "heavyReproduction" // default
            if let presetIndex = args.firstIndex(of: "-FocusStressPreset"), args.count > presetIndex + 1 {
                presetName = args[presetIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            TestRunLogger.shared.startManualTest("Manual_FocusStress_\(presetName)")
            TestRunLogger.shared.log("📱 FocusStressViewController: Starting manual execution")
            TestRunLogger.shared.log("📱 Configuration: \(presetName)")
            TestRunLogger.shared.logSystemInfo()
        }
        
        setupCollectionView()
        
        // Apply stressors based on the configuration
        let stressors = configuration.stress.stressors
        if stressors.contains(.circularFocusGuides) { 
            addCircularGuides()
            TestRunLogger.shared.log("🔄 FocusStressViewController: Circular focus guides activated")
        }
        if stressors.contains(.dynamicFocusGuides) { 
            startDynamicFocusGuides()
            TestRunLogger.shared.log("🔀 FocusStressViewController: Dynamic focus guides activated")
        }
        if stressors.contains(.rapidLayoutChanges) { 
            startRapidLayoutChanges()
            TestRunLogger.shared.log("⚡ FocusStressViewController: Rapid layout changes activated")
        }
        if stressors.contains(.overlappingElements) { 
            addOverlappingElements()
            TestRunLogger.shared.log("🎯 FocusStressViewController: Overlapping elements activated")
        }
        if stressors.contains(.voAnnouncements) { 
            startVOAnnouncements()
            TestRunLogger.shared.log("📢 FocusStressViewController: VoiceOver announcements activated")
        }
        
        // V6.0 memory stress features for guaranteed reproduction
        if ProcessInfo.processInfo.environment["MEMORY_STRESS_ENABLED"] == "1" {
            startMemoryStress()
            TestRunLogger.shared.log("💾 FocusStressViewController: Memory stress enabled for V6.0 reproduction")
        }
        
        // NEW: Start progressive stress system for predictable InfinityBug reproduction
        startProgressiveStressSystem()
        
        // Activate continuous memory stress for extreme presets (guaranteedInfinityBug)
        activateMemoryStress()
        
        AXFocusDebugger.shared.start()
        TestRunLogger.shared.log("🔍 FocusStressViewController: AXFocusDebugger started")
    }

    deinit { 
        jiggleTimer?.invalidate()
        dynamicGuideTimer?.invalidate()
        layoutChangeTimer?.invalidate()
        voAnnouncementTimer?.invalidate()
        memoryStressTimer?.invalidate()
        progressiveStressTimer?.invalidate()
    }

    // MARK: - Progressive Stress System for Predictable InfinityBug Reproduction
    
    /// Systematically escalates system stress to reproduce the InfinityBug pattern:
    /// 0-30s: Baseline (52MB, normal stalls)
    /// 30-90s: Level 1 (56MB, 1-2s stalls)  
    /// 90-180s: Level 2 (64MB, 5-10s stalls)
    /// 180s+: Level 3 (65-66MB, 1000ms+ sustained stalls) → InfinityBug
    private func startProgressiveStressSystem() {
        stressStartTime = CACurrentMediaTime()
        
        TestRunLogger.shared.log("🎯 PROGRESSIVE-STRESS: Starting predictable escalation system")
        TestRunLogger.shared.log("🎯 TARGET: 52MB→56MB→64MB→66MB with escalating stalls")
        
        progressiveStressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateProgressiveStress()
        }
    }
    
    /// Updates stress level based on elapsed time and applies corresponding system pressure
    private func updateProgressiveStress() {
        let elapsed = CACurrentMediaTime() - stressStartTime
        let newStressLevel: Int
        
        // Progressive escalation based on successful reproduction timeline
        switch elapsed {
        case 0..<30:
            newStressLevel = 0 // Baseline: ~52MB
        case 30..<90:
            newStressLevel = 1 // Level 1: ~56MB, 1-2s stalls
        case 90..<180:
            newStressLevel = 2 // Level 2: ~64MB, 5-10s stalls  
        default:
            newStressLevel = 3 // Level 3: 65-66MB, sustained 1000ms+ stalls
        }
        
        if newStressLevel != currentStressLevel {
            escalateStressLevel(to: newStressLevel)
            currentStressLevel = newStressLevel
        }
        
        // Apply continuous stress at current level
        applyCurrentStressLevel()
    }
    
    /// Escalates to the specified stress level with logging
    private func escalateStressLevel(to level: Int) {
        let elapsed = CACurrentMediaTime() - stressStartTime
        
        switch level {
        case 1:
            TestRunLogger.shared.log("🎯 STRESS-ESCALATION: Level 1 at \(String(format: "%.1f", elapsed))s - targeting 56MB")
            addMemoryPressure(targetMB: 56)
            increaseVoiceOverLoad(factor: 1.5)
            
        case 2:
            TestRunLogger.shared.log("🎯 STRESS-ESCALATION: Level 2 at \(String(format: "%.1f", elapsed))s - targeting 64MB")
            addMemoryPressure(targetMB: 64)
            increaseVoiceOverLoad(factor: 2.0)
            artificialStallDuration = 0.1 // Start injecting 100ms stalls
            
        case 3:
            TestRunLogger.shared.log("🎯 STRESS-ESCALATION: Level 3 at \(String(format: "%.1f", elapsed))s - targeting 66MB+ CRITICAL")
            addMemoryPressure(targetMB: 66)
            increaseVoiceOverLoad(factor: 3.0)
            artificialStallDuration = 0.5 // Inject 500ms stalls to trigger 1000ms+ stalls
            
        default:
            TestRunLogger.shared.log("🎯 STRESS-BASELINE: Level 0 - normal operation ~52MB")
        }
    }
    
    /// Adds memory ballast to reach target memory usage
    private func addMemoryPressure(targetMB: Int) {
        let currentMB = estimateCurrentMemoryMB()
        let additionalMB = max(0, targetMB - currentMB)
        
        if additionalMB > 0 {
            // Add ~1MB of strings per call
            let megabyteOfStrings = Array(0..<50000).map { _ in 
                String(repeating: UUID().uuidString, count: 8) // ~32KB each
            }
            memoryBallast.append(megabyteOfStrings)
            
            TestRunLogger.shared.log("🎯 MEMORY-PRESSURE: Added \(additionalMB)MB ballast (target: \(targetMB)MB)")
        }
    }
    
    /// Simulates increasing VoiceOver processing overhead
    private func increaseVoiceOverLoad(factor: Double) {
        voiceOverProcessingLoad = Int(Double(voiceOverProcessingLoad + 10) * factor)
        TestRunLogger.shared.log("🎯 VOICEOVER-LOAD: Increased to level \(voiceOverProcessingLoad)")
    }
    
    /// Applies stress appropriate to current level
    private func applyCurrentStressLevel() {
        // Inject artificial stalls to simulate VoiceOver overhead
        if artificialStallDuration > 0 {
            Thread.sleep(forTimeInterval: artificialStallDuration * 0.1) // 10% of target stall
        }
        
        // Simulate VoiceOver processing by doing accessibility tree queries
        if voiceOverProcessingLoad > 0 && UIAccessibility.isVoiceOverRunning {
            for _ in 0..<min(voiceOverProcessingLoad, 50) {
                _ = view.subviews.count
                _ = collectionView.visibleCells.count
                if artificialStallDuration > 0.2 {
                    // Heavy accessibility queries at high stress levels
                    _ = view.accessibilityElements?.count ?? 0
                }
            }
        }
        
        // Force layout recalculations at higher stress levels
        if currentStressLevel >= 2 {
            collectionView.collectionViewLayout.invalidateLayout()
            view.setNeedsLayout()
            
            // Additional main thread work to create stalls
            if currentStressLevel >= 3 {
                // Expensive string operations to consume main thread time
                _ = memoryBallast.flatMap { $0 }.joined(separator: ",").count
            }
        }
    }
    
    /// Estimates current memory usage (simplified)
    private func estimateCurrentMemoryMB() -> Int {
        // Base memory + accumulated ballast
        let baseMB = 52
        let ballastMB = memoryBallast.count
        return baseMB + ballastMB
    }

    // MARK: Setup helpers
    private func setupCollectionView() {
        collectionView = createCollectionView()
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        let topConstraint = collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        NSLayoutConstraint.activate([
            topConstraint,
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Stress: jiggle autolayout constantly
        if configuration.stress.stressors.contains(.jiggleTimer) {
            jiggleTimer = Timer.scheduledTimer(withTimeInterval: configuration.stress.jiggleInterval, repeats: true) { _ in
                topConstraint.constant = topConstraint.constant == 0 ? 8 : 0
                UIView.performWithoutAnimation { self.view.layoutIfNeeded() }
            }
        }
    }
    
    private func startVOAnnouncements() {
        voAnnouncementTimer = Timer.scheduledTimer(withTimeInterval: configuration.stress.voAnnouncementInterval, repeats: true) { _ in
            guard UIAccessibility.isVoiceOverRunning else { return }
            
            // Enhanced announcements for InfinityBug reproduction
            let randomValue = Int.random(in: 0...99)
            
            if randomValue < 15 { // 15% chance for layout announcements (was 10% for debug)
                // Layout change announcements to stress accessibility system
                let layoutAnnouncements = [
                    "Layout updated with new content",
                    "Collection view structure changed", 
                    "Focus environment refreshed",
                    "Navigation layout modified",
                    "Content arrangement updated",
                    "Display structure reorganized"
                ]
                
                let announcement = layoutAnnouncements.randomElement() ?? "Layout changed"
                
                // Force layout invalidation to create real layout stress
                self.collectionView.collectionViewLayout.invalidateLayout()
                
                // Post layout change notification to stress accessibility system
                UIAccessibility.post(notification: .layoutChanged, argument: announcement)
                
                TestRunLogger.shared.log("📢 LAYOUT-ANNOUNCEMENT: \(announcement)")
                
                // Additional system stress: Force focus system recalculation
                DispatchQueue.main.async {
                    self.view.setNeedsFocusUpdate()
                    self.view.updateFocusIfNeeded()
                }
                
            } else if randomValue < 25 { // 10% chance for regular debug announcements
                let value = Int.random(in: 0...999)
                UIAccessibility.post(notification: .announcement, argument: "Debug announcement \(value)")
            }
        }
    }

    private func addCircularGuides() {
        let guideA = UIFocusGuide()
        let guideB = UIFocusGuide()
        view.addLayoutGuide(guideA)
        view.addLayoutGuide(guideB)

        guideA.preferredFocusEnvironments = [self.collectionView]
        guideB.preferredFocusEnvironments = [self.collectionView]

        [guideA, guideB].forEach {
            $0.widthAnchor.constraint(equalToConstant: 1).isActive = true
            $0.heightAnchor.constraint(equalToConstant: 1).isActive = true
        }
        guideA.topAnchor.constraint(equalTo: view.topAnchor, constant: CGFloat(10)).isActive = true
        guideA.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(10)).isActive = true
        guideB.topAnchor.constraint(equalTo: view.topAnchor, constant: CGFloat(12)).isActive = true
        guideB.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(12)).isActive = true
    }

    /// Stress 6: Constantly changing focus guide configurations
    private func startDynamicFocusGuides() {
        // Create multiple guides that change their preferred environments rapidly
        for i in 0..<5 {
            let guide = UIFocusGuide()
            view.addLayoutGuide(guide)
            guide.widthAnchor.constraint(equalToConstant: 1).isActive = true
            guide.heightAnchor.constraint(equalToConstant: 1).isActive = true
            guide.topAnchor.constraint(equalTo: view.topAnchor, constant: CGFloat(20 + i * 5)).isActive = true
            guide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(20 + i * 5)).isActive = true
            focusGuides.append(guide)
        }

        dynamicGuideTimer = Timer.scheduledTimer(withTimeInterval: configuration.stress.dynamicGuideInterval, repeats: true) { _ in
            self.focusGuides.forEach { guide in
                // Randomly change preferred focus environments
                let environments: [UIFocusEnvironment] = [self.collectionView, self.view, self]
                guide.preferredFocusEnvironments = [environments.randomElement()!]
            }
        }
    }

    /// Stress 7: Rapid layout invalidation cycles
    private func startRapidLayoutChanges() {
        layoutChangeTimer = Timer.scheduledTimer(withTimeInterval: configuration.stress.layoutChangeInterval, repeats: true) { _ in
            // Force layout invalidation at high frequency
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setNeedsLayout()
            self.view.setNeedsLayout()
        }
    }
    
    /// Creates background accessibility stress elements during navigation.
    /// These elements stress the accessibility system similar to conditions in successful reproductions.
    private func addFocusConflicts() {
        NSLog("💾 FocusStressViewController: Adding accessibility stress elements")
        
        // 75+ accessibility elements for system stress during large navigation traversals
        for i in 0..<75 {
            let conflictView = UIView()
            conflictView.isAccessibilityElement = true
            conflictView.accessibilityLabel = "AccessibilityStress\(i % 3)" // Duplicate labels for system confusion
            conflictView.backgroundColor = .clear
            conflictView.alpha = 0.02 // Nearly invisible but still in accessibility tree
            
            // Multiple accessibility traits for system stress
            if i % 5 == 0 {
                conflictView.accessibilityTraits = [.button, .header, .selected] // Multiple conflicting traits
            }
            
            // Dynamic accessibility properties that change during navigation
            conflictView.accessibilityHint = "Background stress element \(i) - navigation pressure"
            
            view.addSubview(conflictView)
            
            // Distributed overlapping frames for accessibility system stress
            conflictView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                conflictView.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: CGFloat(i * 8 - 300)),
                conflictView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: CGFloat(i * 6 - 225)),
                conflictView.widthAnchor.constraint(equalToConstant: 180), // Moderate overlap
                conflictView.heightAnchor.constraint(equalToConstant: 120)
            ])
            
            focusConflictElements.append(conflictView)
        }
        
        // Dynamic accessibility property changes during navigation to stress the system
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Change accessibility properties periodically during navigation
            for (index, element) in self.focusConflictElements.enumerated() {
                if index % 15 == 0 { // Change 1/15 elements each cycle for moderate stress
                    element.accessibilityLabel = "DynamicStress\(Int.random(in: 0...8))"
                    
                    // Trigger accessibility system recalculation
                    UIAccessibility.post(notification: .layoutChanged, argument: nil)
                }
            }
        }
    }

    /// Stress 8: Add overlapping elements for accessibility system stress
    private func addOverlappingElements() {
        // 50+ overlapping elements for accessibility system stress during navigation
        for i in 0..<50 {
            let overlayView = UIView()
            overlayView.isAccessibilityElement = true
            overlayView.accessibilityLabel = "Overlay\(i % 5)" // Duplicate labels for accessibility confusion
            overlayView.backgroundColor = .clear
            overlayView.alpha = 0.01 // Nearly invisible but still in accessibility tree
            
            // Dynamic accessibility properties that change during navigation
            overlayView.accessibilityHint = "Dynamic overlay \(i) - stress element"
            if i % 5 == 0 {
                overlayView.accessibilityTraits = [.button, .header] // Multiple traits for system stress
            }
            
            view.addSubview(overlayView)
            
            overlayView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                // Aggressive overlapping for accessibility system stress
                overlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: CGFloat(i * 15 - 375)),
                overlayView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: CGFloat(i * 12 - 300)),
                overlayView.widthAnchor.constraint(equalToConstant: 300), // Large overlap area
                overlayView.heightAnchor.constraint(equalToConstant: 200)
            ])
        }
    }
    
    // MARK: - V6.0 Memory Stress Features
    
    /// Starts memory stress timer to create system pressure for guaranteed InfinityBug reproduction.
    /// Generates background memory allocations to stress the system similar to successful manual reproductions.
    private func startMemoryStress() {
        NSLog("💾 FocusStressViewController: Starting memory stress for V6.0 reproduction")
        
        memoryStressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Generate memory allocations to stress system
            DispatchQueue.global(qos: .background).async {
                let largeArray = Array(0..<15000).map { _ in UUID().uuidString }
                DispatchQueue.main.async {
                    // Trigger layout calculations with memory pressure
                    _ = largeArray.joined(separator: ",").count
                    
                    // Additional accessibility system stress
                    if UIAccessibility.isVoiceOverRunning {
                        _ = self.view.subviews.count
                    }
                }
            }
        }
        
        // Add focus conflict elements for enhanced stress
        addFocusConflicts()
    }

    // MARK: Layouts
    private func makeSimpleSection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                          heightDimension: .absolute(260))
        let item  = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .paging
        return section
    }

    private func makeNestedSection() -> NSCollectionLayoutSection {
        let innerItem = NSCollectionLayoutItem(layoutSize:
            .init(widthDimension: .absolute(280), heightDimension: .absolute(220)))
        innerItem.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)

        let innerGroup = NSCollectionLayoutGroup.horizontal(layoutSize:
            .init(widthDimension: .absolute(300 * 4), heightDimension: .absolute(240)),
            subitems: [innerItem, innerItem, innerItem, innerItem])
        
        let outerGroup = NSCollectionLayoutGroup.vertical(layoutSize:
            .init(widthDimension: .absolute(300 * 4), heightDimension: .absolute(260)),
            subitems: [innerGroup])

        let section = NSCollectionLayoutSection(group: outerGroup)
        section.orthogonalScrollingBehavior = .groupPaging
        section.interGroupSpacing = 15
        return section
    }

    private func makeTripleNestedSection() -> NSCollectionLayoutSection {
        // Triple nested: Cell -> Horizontal Group -> Vertical Group -> Section
        // This creates maximum layout complexity that can trigger focus calculation bugs
        
        let innerItem = NSCollectionLayoutItem(layoutSize:
            .init(widthDimension: .absolute(280), heightDimension: .absolute(220)))
        innerItem.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        
        let innerGroup = NSCollectionLayoutGroup.horizontal(layoutSize:
            .init(widthDimension: .absolute(300 * 4), heightDimension: .absolute(240)),
            subitems: [innerItem, innerItem, innerItem, innerItem])
        innerGroup.interItemSpacing = .fixed(10)

        // Add a middle layer group for extra nesting chaos
        let middleGroup = NSCollectionLayoutGroup.vertical(layoutSize:
            .init(widthDimension: .absolute(300 * 4), heightDimension: .absolute(260)),
            subitems: [innerGroup])

        let outerGroup = NSCollectionLayoutGroup.horizontal(layoutSize:
            .init(widthDimension: .fractionalWidth(1.2), heightDimension: .absolute(280)),
            subitems: [middleGroup])

        let section = NSCollectionLayoutSection(group: outerGroup)
        section.orthogonalScrollingBehavior = .groupPaging
        section.interGroupSpacing = 15
        
        // Add supplementary views that can interfere with focus
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(1))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: "header", alignment: .top)
        section.boundarySupplementaryItems = [header]
        
        return section
    }

    // MARK: - Memory Stress Implementation
    
    /// Continuous memory allocation stress for InfinityBug reproduction
    /// **Concurrency Requirements:** Runs on background queue with main queue updates
    /// **Usage:** Activated automatically with guaranteedInfinityBug preset
    private func activateMemoryStress() {
        guard configuration.layout.numberOfSections >= 150 else { return } // Only for extreme presets
        
        TestRunLogger.shared.log("💾 MEMORY-STRESS: Activating continuous allocation pressure")
        
        // Continuous memory allocation background task for system pressure
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var allocationCycle = 0
            while self != nil {
                allocationCycle += 1
                
                // Large array allocation every cycle
                let memoryBurst = Array(0..<50000).map { _ in 
                    UUID().uuidString + String(repeating: "stress", count: allocationCycle % 10)
                }
                
                DispatchQueue.main.async { [weak self] in
                    // Force main thread memory pressure with layout calculations
                    _ = memoryBurst.joined(separator: ",").count
                    
                    // Additional UI stress through accessibility tree queries
                    if let strongSelf = self {
                        _ = strongSelf.view.subviews.count
                        _ = strongSelf.collectionView.visibleCells.count
                    }
                    
                    // Log memory pressure progress
                    if allocationCycle % 20 == 0 {
                        TestRunLogger.shared.log("💾 MEMORY-STRESS: Cycle \(allocationCycle) - \(memoryBurst.count) elements allocated")
                    }
                }
                
                // Progressive allocation frequency - starts at 100ms, reduces to 25ms
                let sleepMicros = max(25_000, 100_000 - (allocationCycle * 2_000))
                usleep(UInt32(sleepMicros))
            }
        }
    }
}

// MARK: - Datasource / Delegate
extension FocusStressViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in _: UICollectionView) -> Int { configuration.layout.numberOfSections }
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int { configuration.layout.itemsPerSection }

    func collectionView(_ cv: UICollectionView, cellForItemAt idx: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: StressCell.reuseID, for: idx) as! StressCell
        cell.configure(indexPath: idx, stressConfig: configuration.stress)
        return cell
    }
}

// MARK: - Cell
private final class StressCell: UICollectionViewCell {
    static let reuseID = "StressCell"
    private var host: UIHostingController<SwiftUIView>?

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.backgroundColor = .systemBlue
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } else {
                self.backgroundColor = .darkGray
                self.transform = .identity
            }
        }, completion: nil)
    }

    func configure(indexPath: IndexPath, stressConfig: StressorConfiguration) {
        backgroundColor = isFocused ? .systemBlue : .darkGray

        // Stress 5: duplicate IDs
        accessibilityIdentifier = stressConfig.stressors.contains(.duplicateIdentifiers) && indexPath.item % 3 == 0
            ? "dupCell"
            : "cell-\(indexPath.section)-\(indexPath.item)"

        // ENHANCED INFINITY BUG STRESS: Rapid accessibility changes during configuration
        if stressConfig.stressors.contains(.voAnnouncements) {
            // Change accessibility properties rapidly to stress the system
            accessibilityLabel = "Cell \(indexPath.section)-\(indexPath.item) Dynamic \(Int.random(in: 0...999))"
            accessibilityHint = "Changes every configuration - stress element \(indexPath.item % 10)"
            
            // Conflicting accessibility traits to confuse the system
            if indexPath.item % 7 == 0 {
                accessibilityTraits = [.button, .header, .adjustable] // Multiple conflicting traits
            }
            
            // Force rapid focus calculations by querying focus state
            _ = canBecomeFocused
            _ = isFocused
        }

        if host == nil {
            let view = SwiftUIView(number: indexPath.item)
            let hosting = UIHostingController(rootView: view)
            hosting.view.backgroundColor = .clear
            contentView.addSubview(hosting.view)
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            ])
            host = hosting
        }

        // Stress 2: hidden focusable traps - MORE AGGRESSIVE version
        if stressConfig.stressors.contains(.hiddenFocusableTraps) && contentView.subviews.filter({ $0.isHidden }).isEmpty {
            // INCREASED from 8 to 15 traps per cell for maximum confusion
            for i in 0..<15 {
                let trap = UIView()
                trap.isAccessibilityElement = true
                trap.accessibilityLabel = "HiddenTrap\(i % 4)" // More duplicate labels
                trap.isHidden = Bool.random() // Some visible, some hidden
                trap.alpha = trap.isHidden ? 0 : 0.05
                trap.backgroundColor = .red
                
                // Additional accessibility stress during cell configuration
                trap.accessibilityHint = "Hidden stress trap \(i)"
                
                // CONFLICTING TRAITS for more system confusion
                if i % 5 == 0 {
                    trap.accessibilityTraits = [.button, .image, .selected]
                }
                
                contentView.addSubview(trap)
                
                trap.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    // SMALLER spacing for more aggressive overlap
                    trap.centerXAnchor.constraint(equalTo: contentView.centerXAnchor, constant: CGFloat(i * 8 - 56)),
                    trap.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: CGFloat(i * 6 - 42)),
                    trap.widthAnchor.constraint(equalToConstant: 25), // Larger traps
                    trap.heightAnchor.constraint(equalToConstant: 20)
                ])
            }
        }
        
        // NEW STRESS: Force layout calculations during configuration to stress the system
        contentView.setNeedsLayout()
        contentView.layoutIfNeeded()
        
        // Force accessibility tree recalculation
        if UIAccessibility.isVoiceOverRunning {
            _ = contentView.subviews.count // Force accessibility query
        }
    }
}

// MARK: - SwiftUI bridge
private struct SwiftUIView: View {
    let number: Int
    var body: some View {
        ZStack { Color.clear; Text("Item \(number)").foregroundColor(.white) }
    }
}