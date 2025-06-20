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
//  
//  Visual feedback: Focused cells turn blue with 1.05x scale
//

import UIKit
import SwiftUI

// MARK: - StressFlags

/// Individual stressors can be toggled via launch arguments.
/// Heavy mode = all on, light = only 1 & 2 on.
struct StressFlags {
    var nestedLayout            = true   // 1
    var hiddenFocusableTraps    = true   // 2
    var jiggleTimer             = true   // 3
    var circularFocusGuides     = true   // 4
    var duplicateIdentifiers    = true   // 5
    var dynamicFocusGuides      = true   // 6
    var rapidLayoutChanges      = true   // 7
    var overlappingElements     = true   // 8

    /// Build flags from ProcessInfo.
    static func parse() -> StressFlags {
        var f = StressFlags()
        let args = ProcessInfo.processInfo.arguments

        // Light mode via launch arguments
        if args.contains("-FocusStressMode") && args.contains("light") {
            f.jiggleTimer          = false
            f.circularFocusGuides  = false
            f.duplicateIdentifiers = false
            f.dynamicFocusGuides   = false
            f.rapidLayoutChanges   = false
            f.overlappingElements  = false
        }

        // Light mode via user defaults (from menu navigation)
        if let stored = UserDefaults.standard.string(forKey: "FocusStressMode"), stored == "light" {
            f.jiggleTimer          = false
            f.circularFocusGuides  = false
            f.duplicateIdentifiers = false
            f.dynamicFocusGuides   = false
            f.rapidLayoutChanges   = false
            f.overlappingElements  = false
        }

        // EnableStress<n> YES overrides for targeted runs
        func on(_ n: Int) -> Bool { args.contains("-EnableStress\(n)") }
        if on(1) { f.nestedLayout         = true  }
        if on(2) { f.hiddenFocusableTraps = true  }
        if on(3) { f.jiggleTimer          = true  }
        if on(4) { f.circularFocusGuides  = true  }
        if on(5) { f.duplicateIdentifiers = true  }
        if on(6) { f.dynamicFocusGuides   = true  }
        if on(7) { f.rapidLayoutChanges   = true  }
        if on(8) { f.overlappingElements  = true  }
        return f
    }
}

// MARK: - FocusStressViewController

/// DEBUG‑only VC that intentionally degrades focus performance for diagnostics.
final class FocusStressViewController: UIViewController {

    // MARK: Properties
    private let flags = StressFlags.parse()
    private var jiggleTimer: Timer?
    private var dynamicGuideTimer: Timer?
    private var layoutChangeTimer: Timer?
    private var focusGuides: [UIFocusGuide] = []

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            self.flags.nestedLayout ? self.makeNestedSection() : self.makeSimpleSection()
        }
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.remembersLastFocusedIndexPath = true
        cv.dataSource = self
        cv.delegate   = self
        cv.isPrefetchingEnabled = false
        cv.accessibilityIdentifier = "FocusStressCollectionView"
        cv.register(StressCell.self, forCellWithReuseIdentifier: StressCell.reuseID)
        return cv
    }()

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCollectionView()
        if flags.circularFocusGuides { addCircularGuides() }
        if flags.dynamicFocusGuides { startDynamicFocusGuides() }
        if flags.rapidLayoutChanges { startRapidLayoutChanges() }
        if flags.overlappingElements { addOverlappingElements() }
        AXFocusDebugger.shared.start()
    }

    deinit { 
        jiggleTimer?.invalidate()
        dynamicGuideTimer?.invalidate()
        layoutChangeTimer?.invalidate()
    }

    // MARK: Setup helpers
    private func setupCollectionView() {
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        let topConstraint = collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        NSLayoutConstraint.activate([
            topConstraint,
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Stress 3: jiggle autolayout constantly
        if flags.jiggleTimer {
            jiggleTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                topConstraint.constant = topConstraint.constant == 0 ? 8 : 0
                UIView.performWithoutAnimation { self.view.layoutIfNeeded() }
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

        dynamicGuideTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.focusGuides.forEach { guide in
                // Randomly change preferred focus environments
                let environments: [UIFocusEnvironment] = [self.collectionView, self.view, self]
                guide.preferredFocusEnvironments = [environments.randomElement()!]
            }
        }
    }

    /// Stress 7: Rapid layout invalidation cycles
    private func startRapidLayoutChanges() {
        layoutChangeTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            // Force layout invalidation at high frequency
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.setNeedsLayout()
            self.view.setNeedsLayout()
        }
    }

    /// Stress 8: Add overlapping invisible focusable elements
    private func addOverlappingElements() {
        for i in 0..<10 {
            let overlayView = UIView()
            overlayView.isAccessibilityElement = true
            overlayView.accessibilityLabel = "Overlay\(i)"
            overlayView.backgroundColor = .clear
            overlayView.alpha = 0.01 // Nearly invisible but still focusable
            view.addSubview(overlayView)
            
            overlayView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                overlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: CGFloat(i * 20 - 100)),
                overlayView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: CGFloat(i * 15 - 75)),
                overlayView.widthAnchor.constraint(equalToConstant: 200),
                overlayView.heightAnchor.constraint(equalToConstant: 150)
            ])
        }
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
}



// MARK: - Datasource / Delegate
extension FocusStressViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in _: UICollectionView) -> Int { 25 }
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int { 35 }

    func collectionView(_ cv: UICollectionView, cellForItemAt idx: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: StressCell.reuseID, for: idx) as! StressCell
        cell.configure(indexPath: idx, flags: flags)
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

    func configure(indexPath: IndexPath, flags: StressFlags) {
        backgroundColor = isFocused ? .systemBlue : .darkGray

        // Stress 5: duplicate IDs
        accessibilityIdentifier = flags.duplicateIdentifiers && indexPath.item % 3 == 0
            ? "dupCell"
            : "cell-\(indexPath.section)-\(indexPath.item)"

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

        // Stress 2: hidden focusable traps - more aggressive version
        if flags.hiddenFocusableTraps && contentView.subviews.filter({ $0.isHidden }).isEmpty {
            for i in 0..<8 {
                let trap = UIView()
                trap.isAccessibilityElement = true
                trap.accessibilityLabel = "HiddenTrap\(i)"
                trap.isHidden = Bool.random() // Some visible, some hidden
                trap.alpha = trap.isHidden ? 0 : 0.05
                trap.backgroundColor = .red
                contentView.addSubview(trap)
                
                trap.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    trap.centerXAnchor.constraint(equalTo: contentView.centerXAnchor, constant: CGFloat(i * 10 - 40)),
                    trap.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: CGFloat(i * 8 - 32)),
                    trap.widthAnchor.constraint(equalToConstant: 20),
                    trap.heightAnchor.constraint(equalToConstant: 15)
                ])
            }
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
