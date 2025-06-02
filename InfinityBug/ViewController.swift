// MARK: – UIView extension for finding containing UICollectionViewCell
private extension UIView {
    /// Walks up the view hierarchy to find the nearest UICollectionViewCell, if any.
    func containingCollectionViewCell() -> UICollectionViewCell? {
        var view: UIView? = self
        while let current = view, !(current is UICollectionViewCell) {
            view = current.superview
        }
        return view as? UICollectionViewCell
    }
}
//
//  ViewController.swift
//  InfinityBug
//
//  Created by Joseph McCraw on 6/1/25.
//

//import UIKit
//
//class ViewController: UIViewController {
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        // Do any additional setup after loading the view.
//    }
//
//
//}



import UIKit

/// A custom cell that draws a green border when focused.
class HighlightCollectionViewCell: UICollectionViewCell {
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if context.nextFocusedView === self {
            self.layer.borderWidth = 4
            self.layer.borderColor = UIColor.green.cgColor
        } else if context.previouslyFocusedView === self {
            self.layer.borderWidth = 0
        }
    }
}

/// Our main view controller for the tvOS EPG example.
final class ViewController: UIViewController {
    // MARK: – Configurable Constants
    
    /// Number of genres (categories).  e.g. `["Horror", "Comedy", "Drama", ...]`.
    private let genreNames: [String] = [
        "Horror", "Comedy", "Drama", "Sports",
        "Kids", "Documentary", "News", "Music"
    ]
    
    /// Number of channels per genre.  Let’s say 10 per category by default.
    private let channelsPerGenre: Int = 10
    
    /// Number of listings (episodes) per channel (carousel length).
    private let listingsPerChannel: Int = 20
    
    /// Simulated network delay (in seconds) for each channel’s listings.
    private let simulatedDelaySeconds: TimeInterval = 1.0
    
    /// Category column width (points).
    private let categoryColumnWidth: CGFloat = 250
    
    // MARK: – UI Elements
    
    /// Left side: list of genres (categories).
    private lazy var categoriesCollectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment -> NSCollectionLayoutSection? in
            return self?.createCategoryListSection()
        }
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .black
        cv.remembersLastFocusedIndexPath = true
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.allowsFocus = true
        cv.accessibilityIdentifier = "CategoriesCollectionView"
        return cv
    }()
    
    /// Right side: the EPG.
    private lazy var epgCollectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment -> NSCollectionLayoutSection? in
            return self?.createChannelSection(forSection: sectionIndex, in: environment)
        }
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .black
        cv.remembersLastFocusedIndexPath = true
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.isPrefetchingEnabled = true
        cv.prefetchDataSource = self
        cv.accessibilityIdentifier = "EPGCollectionView"
        return cv
    }()
    
    // MARK: – Diffable Data Sources
    
    /// Section for categories view only has one section (we'll call it Section.main).
    private enum CategorySection { case main }
    private var categoryDataSource: UICollectionViewDiffableDataSource<CategorySection, Genre>!
    
    /// For EPG, each "section" is a Channel.  We’ll use the Channel object as our section identifier.
    private var epgDataSource: UICollectionViewDiffableDataSource<Channel, Listing>!
    
    // MARK: – Data Storage
    
    /// Complete list of `Genre` objects (left-hand side).
    private var genres: [Genre] = []
    
    /// Complete list of `Channel` objects (each has a genre, name, and eventually listings).
    /// Note: We store these in an array.  The index of `channels[i]` corresponds to section `i` in epgCollectionView.
    private var channels: [Channel] = []
    
    // A lookup from Channel.id -> its position in `channels[]` (so we know which section to reload).
    private var channelIndexLookup: [UUID: Int] = [:]
    
    // MARK: – Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        configureGenresAndChannels()
        configureCategoryCollectionView()
        configureEPGCollectionView()
        performInitialSnapshots()
        simulateAsyncLoadingForAllChannels()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure the focus environment updates after layout changes.
        epgCollectionView.collectionViewLayout.invalidateLayout()
    }
    
    // MARK: – Setup Data Models
    
    private func configureGenresAndChannels() {
        // 1. Create Genre objects from genreNames
        genres = genreNames.map { Genre(name: $0) }
        
        // 2. Create `channelsPerGenre * genres.count` channels, assign genre accordingly.
        //    e.g. first 10 => "Horror", next 10 => "Comedy", etc.
        var tempChannels: [Channel] = []
        for (genreIndex, genre) in genres.enumerated() {
            for channelIdx in 0..<channelsPerGenre {
                let channelNumber = genreIndex * channelsPerGenre + channelIdx + 1
                let channelName = "\(genre.name) Channel \(channelIdx + 1)"
                var channel = Channel(name: channelName, genre: genre)
                tempChannels.append(channel)
            }
        }
        channels = tempChannels
        
        // 3. Build lookup from Channel.id -> its index in `channels[]`
        for (idx, chan) in channels.enumerated() {
            channelIndexLookup[chan.id] = idx
        }
        
        print("[DEBUG] Configured \(genres.count) genres and \(channels.count) total channels.")
    }
    
    // MARK: – Category Collection View (Left Column)
    
    private func configureCategoryCollectionView() {
        view.addSubview(categoriesCollectionView)
        
        NSLayoutConstraint.activate([
            categoriesCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoriesCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
            categoriesCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            categoriesCollectionView.widthAnchor.constraint(equalToConstant: categoryColumnWidth)
        ])
        
        // Register a simple cell for genres
        let registration = UICollectionView.CellRegistration<HighlightCollectionViewCell, Genre> { cell, indexPath, genre in
            var content = UIListContentConfiguration.cell()
            content.text = genre.name
            content.textProperties.color = .white
            content.textProperties.font = .systemFont(ofSize: 24, weight: .medium)
            cell.contentConfiguration = content
            cell.backgroundColor = .darkGray
            cell.accessibilityLabel = "Genre: \(genre.name)"
            cell.accessibilityTraits = .button
        }
        
        categoryDataSource = UICollectionViewDiffableDataSource<CategorySection, Genre>(collectionView: categoriesCollectionView) {
            collectionView, indexPath, genre -> UICollectionViewCell? in
            return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: genre)
        }
        
        // Initial snapshot (empty for now, we'll apply real data below)
        var snapshot = NSDiffableDataSourceSnapshot<CategorySection, Genre>()
        snapshot.appendSections([.main])
        snapshot.appendItems(genres, toSection: .main)
        categoryDataSource.apply(snapshot, animatingDifferences: false)
        
        // Highlight nothing initially
        categoriesCollectionView.selectItem(at: nil, animated: false, scrollPosition: [])
        
        categoriesCollectionView.delegate = self
    }
    
    // MARK: – EPG (Right Column) Collection View
    
    private func configureEPGCollectionView() {
        view.addSubview(epgCollectionView)
        
        NSLayoutConstraint.activate([
            epgCollectionView.leadingAnchor.constraint(equalTo: categoriesCollectionView.trailingAnchor),
            epgCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            epgCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
            epgCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Register channel header supplementary for channel names
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionReusableView>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] supplementaryView, elementKind, indexPath in
            guard let self = self else { return }
            let channel = self.channels[indexPath.section]
            let labelTag = 1001
            if let existing = supplementaryView.viewWithTag(labelTag) as? UILabel {
                existing.text = channel.name
            } else {
                let label = UILabel(frame: supplementaryView.bounds)
                label.tag = labelTag
                label.translatesAutoresizingMaskIntoConstraints = false
                label.font = .systemFont(ofSize: 22, weight: .bold)
                label.textColor = .white
                label.text = channel.name
                label.accessibilityLabel = "Channel: \(channel.name)"
                supplementaryView.addSubview(label)
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: supplementaryView.leadingAnchor, constant: 16),
                    label.trailingAnchor.constraint(equalTo: supplementaryView.trailingAnchor, constant: -16),
                    label.topAnchor.constraint(equalTo: supplementaryView.topAnchor),
                    label.bottomAnchor.constraint(equalTo: supplementaryView.bottomAnchor)
                ])
            }
            supplementaryView.tag = indexPath.section
            supplementaryView.backgroundColor = .black
        }
        
        // Cell registration for “listing” items
        let listingRegistration = UICollectionView.CellRegistration<HighlightCollectionViewCell, Listing> { cell, indexPath, listing in
            // A very simple cell: just a colored box with a centered title.
            cell.contentView.layer.cornerRadius = 8
            cell.contentView.layer.masksToBounds = true
            cell.contentView.backgroundColor = listing.artworkColor
            
            // Remove any existing label before adding new one
            let labelTag = 2001
            if let existing = cell.contentView.viewWithTag(labelTag) as? UILabel {
                existing.text = listing.title
            } else {
                let label = UILabel()
                label.tag = labelTag
                label.translatesAutoresizingMaskIntoConstraints = false
                label.font = .systemFont(ofSize: 16, weight: .semibold)
                label.textColor = .black
                label.textAlignment = .center
                label.numberOfLines = 2
                label.text = listing.title
                cell.contentView.addSubview(label)
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 4),
                    label.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -4),
                    label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
                ])
            }
            
            cell.accessibilityLabel = "Listing: \(listing.title)"
            cell.accessibilityTraits = .button
        }
        
        epgDataSource = UICollectionViewDiffableDataSource<Channel, Listing>(collectionView: epgCollectionView) {
            (collectionView, indexPath, listing) -> UICollectionViewCell? in
            return collectionView.dequeueConfiguredReusableCell(using: listingRegistration, for: indexPath, item: listing)
        }
        
        epgDataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }
            return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
        
        epgCollectionView.delegate = self
    }
    
    // MARK: – Layout Definitions
    
    /// Creates one “channel section” in the EPG. Each channel is a section, with a header and a horizontal carousel of listings.
    private func createChannelSection(forSection sectionIndex: Int, in environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        // 1. Item size: fixed 200×120
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(200),
            heightDimension: .absolute(120)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        
        // 2. Group: horizontal group showing, say, 3 items per “page” (but can scroll)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.9),
            heightDimension: .absolute(128)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 3)
        
        // 3. Section: a group, orthogonally scrolling
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 8
        
        // 4. Channel header
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(50)
        )
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [sectionHeader]
        
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0)
        return section
    }
    
    /// Creates the single section for the Categories list (one vertical list, full height cells of fixed size).
    private func createCategoryListSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(60)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(68)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitem: item, count: 1)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
        return section
    }
    
    // MARK: – Initial Snapshot Population
    
    private func performInitialSnapshots() {
        // 1. Categories: already applied in configureCategoryCollectionView()
        
        // 2. EPG: initially add all channels with zero listings (we’ll patch in listings later)
        var snapshot = NSDiffableDataSourceSnapshot<Channel, Listing>()
        for channel in channels {
            snapshot.appendSections([channel])
            // No items yet; we’ll populate suddenly after simulated delay
            snapshot.appendItems([], toSection: channel)
        }
        epgDataSource.apply(snapshot, animatingDifferences: false)
    }
    
    // MARK: – Simulated Async Loading
    
    /// Loop through every channel and simulate an asynchronous “network” fetch for its listings.
    private func simulateAsyncLoadingForAllChannels() {
        for (index, channel) in channels.enumerated() {
            let channelID = channel.id
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + simulatedDelaySeconds + Double(index) * 0.05) {
                // We introduce a slight stagger (0.05s per channel) to avoid flooding main thread all at once.
                self.fetchListings(forChannelID: channelID)
            }
        }
    }
    
    /// Simulates “fetching” listings for a given channel by sleeping, then creating fake Listing items, then updating the diffable snapshot.
    private func fetchListings(forChannelID channelID: UUID) {
        // 1. Sleep to simulate network latency
        print("[DEBUG] Starting async fetch for channel \(channelID). Sleeping for \(simulatedDelaySeconds)s…")
        Thread.sleep(forTimeInterval: simulatedDelaySeconds)
        
        // 2. Create fake timetable-style listings
        var newListings: [Listing] = []
        for idx in 1...listingsPerChannel {
            // Generate a mock time slot (e.g., 00:00, 00:30, 01:00, etc.)
            let totalMinutes = (idx - 1) * 30
            let hour = (totalMinutes / 60) % 24
            let minute = totalMinutes % 60
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
            let timeString = formatter.string(from: date)
            let showName = "Show \(idx)"
            let title = "\(timeString) – \(showName)"
            let listing = Listing(title: title)
            newListings.append(listing)
        }
        
        // 3. Find which section index corresponds to channelID
        guard let sectionIndex = channelIndexLookup[channelID] else {
            print("[ERROR] Channel ID \(channelID) not found in lookup.")
            return
        }
        
        // 4. Update our local `channels[sectionIndex].listings`
        channels[sectionIndex].listings = newListings
        
        // 5. UI update on main thread: append items to the section’s snapshot
        DispatchQueue.main.async {
            var currentSnapshot = self.epgDataSource.snapshot()
            let channelSection = self.channels[sectionIndex]
            currentSnapshot.deleteSections([channelSection])
            currentSnapshot.appendSections([channelSection])
            currentSnapshot.appendItems(newListings, toSection: channelSection)
            
            self.epgDataSource.apply(currentSnapshot, animatingDifferences: true) {
                print("[DEBUG] Applied snapshot for channel section \(sectionIndex) with \(newListings.count) listings.")
            }
        }
    }
    
    // MARK: – Focus & Category Highlighting
    
    /// Whenever focus updates in the EPG, we want to reflect which category is “active” on the left.
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        guard let nextFocused = context.nextFocusedView else { return }

        // If focus moved into the EPG collection view or one of its cells
        if nextFocused.isDescendant(of: epgCollectionView) {
            // 1. Try finding a cell
            if let cell = nextFocused.containingCollectionViewCell(),
               let indexPath = epgCollectionView.indexPath(for: cell),
               indexPath.section < channels.count
            {
                let focusedChannel = channels[indexPath.section]
                highlightCategory(for: focusedChannel.genre)
            }
            // 2. If it's a header supplementary view (tagged), use that
            else if let header = nextFocused as? UICollectionReusableView {
                let section = header.tag
                if section < channels.count {
                    let focusedChannel = channels[section]
                    highlightCategory(for: focusedChannel.genre)
                }
            }
        }
        // If focus moved into the categories collection view, allow proper focus transfer
        else if nextFocused.isDescendant(of: categoriesCollectionView) {
            // Optionally, you could de-select any previously highlighted genre if desired.
        }
    }
    
    /// Selects the given genre in the categoriesCollectionView (and scrolls it into view).
    private func highlightCategory(for genre: Genre) {
        guard let index = genres.firstIndex(of: genre) else { return }
        let indexPath = IndexPath(item: index, section: 0)
        categoriesCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredVertically)
        
        print("[DEBUG] Highlighting genre '\(genre.name)' at index \(index).")
    }
}

// MARK: – UICollectionViewDataSourcePrefetching

extension ViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // If desired, kick off preloading images or data here.
        // In our mock example, everything is local, so no prefetch is strictly needed.
        print("[DEBUG] Prefetching items at indexPaths: \(indexPaths)")
    }
}

// MARK: – UICollectionViewDelegate (Category Taps)

extension ViewController: UICollectionViewDelegate {
    // When the user clicks/taps on a category, scroll to that genre’s first channel section.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == categoriesCollectionView {
            let selectedGenre = genres[indexPath.item]
            // Find the first channel in `channels[]` whose genre matches.
            if let firstChannelIndex = channels.firstIndex(where: { $0.genre == selectedGenre }) {
                let targetSection = firstChannelIndex
                let targetIndexPath = IndexPath(item: 0, section: targetSection)
                epgCollectionView.scrollToItem(at: targetIndexPath, at: .top, animated: true)
                print("[DEBUG] Category '\(selectedGenre.name)' tapped—scrolling to channel section #\(targetSection).")
            }
        }
    }
}
