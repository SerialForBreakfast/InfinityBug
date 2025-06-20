#if DEBUG
//
//  FocusStressViewController.swift
//  HammerTime
//
//  Purpose: Reproduce the "InfinityBug" by combining multiple worst‑case
//  focus and accessibility stressors.  Excluded from RELEASE builds.
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

    /// Build flags from ProcessInfo.
    static func parse() -> StressFlags {
        var f = StressFlags()
        let args = ProcessInfo.processInfo.arguments

        // Light mode reduces stress
        if args.contains("-FocusStressMode") && args.contains("light") {
            f.jiggleTimer          = false
            f.circularFocusGuides  = false
            f.duplicateIdentifiers = false
        }

        // EnableStress<n> YES overrides for targeted runs
        func on(_ n: Int) -> Bool { args.contains("-EnableStress\(n)") }
        if on(1) { f.nestedLayout         = true  }
        if on(2) { f.hiddenFocusableTraps = true  }
        if on(3) { f.jiggleTimer          = true  }
        if on(4) { f.circularFocusGuides  = true  }
        if on(5) { f.duplicateIdentifiers = true  }
        return f
    }
}

// MARK: - FocusStressViewController

/// DEBUG‑only VC that intentionally degrades focus performance for diagnostics.
final class FocusStressViewController: UIViewController {

    // MARK: Properties
    private let flags = StressFlags.parse()
    private var jiggleTimer: Timer?

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
    }

    deinit { jiggleTimer?.invalidate() }

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
        // Cell inside horizontal group inside vertical group
        let innerItem = NSCollectionLayoutItem(layoutSize:
            .init(widthDimension: .absolute(300), heightDimension: .absolute(240)))
        let innerGroup = NSCollectionLayoutGroup.horizontal(layoutSize:
            .init(widthDimension: .absolute(300 * 3), heightDimension: .absolute(240)),
            subitems: [innerItem, innerItem, innerItem])

        let outerGroup = NSCollectionLayoutGroup.vertical(layoutSize:
            .init(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(260)),
            subitems: [innerGroup])

        let section = NSCollectionLayoutSection(group: outerGroup)
        section.orthogonalScrollingBehavior = .groupPaging
        section.interGroupSpacing = 20
        return section
    }
}

// MARK: - Datasource / Delegate
extension FocusStressViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in _: UICollectionView) -> Int { 12 }
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int { 20 }

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

    func configure(indexPath: IndexPath, flags: StressFlags) {
        backgroundColor = .darkGray

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

        // Stress 2: hidden focusable traps
        if flags.hiddenFocusableTraps && contentView.subviews.filter({ $0.isHidden }).isEmpty {
            for _ in 0..<3 {
                let trap = UIView()
                trap.isAccessibilityElement = true
                trap.accessibilityLabel = "HiddenTrap"
                trap.isHidden = true
                trap.frame = .zero
                contentView.addSubview(trap)
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
#endif
