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
/// 
/// ARCHITECTURE OVERVIEW:
/// 1. DATA MODEL:
///    - Genres: Categories like "Horror", "Comedy", "Sports", etc.
///    - Channels: Each genre has multiple channels (e.g., "Horror Channel 1", "Horror Channel 2")
///    - Listings: Each channel has multiple time-slotted shows (e.g., "10:00 AM – Horror Show 3")
///
/// 2. COLLECTION VIEW STRUCTURE:
///    - Left column: Categories (genres) - vertical list
///    - Top header: Horizontal categories for quick navigation
///    - Main area: EPG grid where each channel is a SECTION, and listings are ITEMS within that section
///
/// 3. DATA FLOW:
///    - App starts: Create empty sections for all channels (no listings yet)
///    - Async loading: Each channel fetches its listings on a background thread with staggered delays
///    - UI updates: When listings are ready, update the diffable data source snapshot
///
/// 4. POTENTIAL ISSUES:
///    - If a channel's async fetch fails or doesn't complete, that channel will show no listings
///    - Out-of-bounds errors occur when collection view requests more sections than we have channels
///    - Snapshot inconsistencies can cause missing listings or crashes
final class ViewController: UIViewController {
    // MARK: – Configurable Constants
    private let genreNames: [String] = ["Horror", "Comedy", "Drama", "Sports", "Kids", "Documentary", "News", "Music"]
    private let channelsPerGenre: Int = 10
    private let listingsPerChannel: Int = 20
    private let simulatedDelaySeconds: TimeInterval = 1.0
    private let categoryColumnWidth: CGFloat = 250

    // MARK: – UI Elements
    private lazy var categoriesCollectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ -> NSCollectionLayoutSection? in
            // Reuse the same section definition from createCategoryListSection()
            return self.createCategoryListSection()
        }
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .black
        cv.remembersLastFocusedIndexPath = true
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.accessibilityIdentifier = "CategoriesCollectionView"
        cv.accessibilityLabel = "Categories"
        return cv
    }()
    private lazy var headerCategoryCollectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ -> NSCollectionLayoutSection? in
            // One‐item horizontal group
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .estimated(120),
                heightDimension: .absolute(44)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .estimated(120),
                heightDimension: .absolute(52)
            )
            // **DEPRECATED replaced by subitems:**
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitems: [item]
            )
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            return section
        }
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .darkGray
        cv.remembersLastFocusedIndexPath = true
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.accessibilityIdentifier = "HeaderCategoryCollectionView"
        cv.accessibilityLabel = "Header Categories"
        return cv
    }()
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
        cv.accessibilityLabel = "EPG Channel Listings"
        return cv
    }()

    // MARK: – Diffable Data Sources
    private enum CategorySection { case main }
    private var categoryDataSource: UICollectionViewDiffableDataSource<CategorySection, Genre>!
    private var epgDataSource: UICollectionViewDiffableDataSource<Genre, Listing>!
    private var headerCategoryDataSource: UICollectionViewDiffableDataSource<CategorySection, Genre>!

    // MARK: – Data Storage
    private var genres: [Genre] = []
    private var channels: [Channel] = []
    private var channelIndexLookup: [UUID: Int] = [:]
    
    // Serial queue to ensure snapshot updates happen one at a time
    private let snapshotUpdateQueue = DispatchQueue(label: "com.epg.snapshot.updates", qos: .userInitiated)

    // MARK: – Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.accessibilityLabel = "EPG Main View"

        configureGenresAndChannels()
        configureCategoryCollectionView()
        configureHeaderCategoryCollectionView()
        configureEPGCollectionView()
        performInitialHeaderSnapshot()
        performInitialSnapshots()
        simulateAsyncLoadingForAllChannels()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        epgCollectionView.collectionViewLayout.invalidateLayout()
    }

    // MARK: – Setup Data Models
    private func configureGenresAndChannels() {
        // Create genres from the predefined genre names
        genres = genreNames.map { Genre(name: $0) }

        // Create channels: for each genre, create channelsPerGenre number of channels
        // This creates a total of genreNames.count * channelsPerGenre channels
        // For example: 8 genres * 10 channels = 80 total channels
        var tempChannels: [Channel] = []
        for genre in genres {
            for channelIdx in 0..<channelsPerGenre {
                let channelName = "\(genre.name) Channel \(channelIdx + 1)"
                let channel = Channel(name: channelName, genre: genre)
                tempChannels.append(channel)
            }
        }
        channels = tempChannels

        // Create a lookup dictionary to quickly find a channel's index by its UUID
        // This is used later in fetchListings to locate which channel to update
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
        // Register cell for categories (genre names) with accessibility label
        let categoryRegistration = UICollectionView.CellRegistration<HighlightCollectionViewCell, Genre> { cell, indexPath, genre in
            var content = UIListContentConfiguration.cell()
            content.text = genre.name
            content.textProperties.color = .white
            content.textProperties.font = .systemFont(ofSize: 24, weight: .medium)
            cell.contentConfiguration = content
            cell.backgroundColor = .darkGray
            cell.accessibilityLabel = "Category: \(genre.name)"
            cell.accessibilityTraits = .button
        }
        categoryDataSource = UICollectionViewDiffableDataSource<CategorySection, Genre>(
            collectionView: categoriesCollectionView
        ) { collectionView, indexPath, genre in
            return collectionView.dequeueConfiguredReusableCell(using: categoryRegistration, for: indexPath, item: genre)
        }
        categoriesCollectionView.delegate = self

        // Initial snapshot for categories
        var categorySnapshot = NSDiffableDataSourceSnapshot<CategorySection, Genre>()
        categorySnapshot.appendSections([.main])
        categorySnapshot.appendItems(genres, toSection: .main)
        categoryDataSource.apply(categorySnapshot, animatingDifferences: false)
    }

    // MARK: – Header Category Collection View (Top Horizontal Bar)
    private func configureHeaderCategoryCollectionView() {
        let registration = UICollectionView.CellRegistration<HighlightCollectionViewCell, Genre> { cell, indexPath, genre in
            var content = UIListContentConfiguration.cell()
            content.text = genre.name
            content.textProperties.color = .white
            content.textProperties.font = .systemFont(ofSize: 18, weight: .semibold)
            cell.contentConfiguration = content
            cell.backgroundColor = .gray
            cell.accessibilityLabel = "Jump to genre: \(genre.name)"
            cell.accessibilityTraits = .button
        }
        headerCategoryDataSource = UICollectionViewDiffableDataSource<CategorySection, Genre>(
            collectionView: headerCategoryCollectionView
        ) { collectionView, indexPath, genre in
            return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: genre)
        }
        headerCategoryCollectionView.delegate = self
    }

    private func performInitialHeaderSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<CategorySection, Genre>()
        snapshot.appendSections([.main])
        snapshot.appendItems(genres, toSection: .main)
        headerCategoryDataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: – EPG (Right Column) Collection View
    private func configureEPGCollectionView() {
        view.addSubview(headerCategoryCollectionView)
        view.addSubview(epgCollectionView)

        NSLayoutConstraint.activate([
            // Position the header bar
            headerCategoryCollectionView.leadingAnchor.constraint(equalTo: categoriesCollectionView.trailingAnchor),
            headerCategoryCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerCategoryCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
            headerCategoryCollectionView.heightAnchor.constraint(equalToConstant: 52),

            // Place the EPG collection view below the header
            epgCollectionView.leadingAnchor.constraint(equalTo: categoriesCollectionView.trailingAnchor),
            epgCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            epgCollectionView.topAnchor.constraint(equalTo: headerCategoryCollectionView.bottomAnchor),
            epgCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Register channel header supplementary
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionReusableView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] supplementaryView, elementKind, indexPath in
            guard let self = self else { return }
            print("[DEBUG] SupplementaryView: indexPath.section=\(indexPath.section), genres.count=\(self.genres.count)")
            let snapshot = self.epgDataSource.snapshot()
            print("[DEBUG] SupplementaryView: snapshot section count = \(snapshot.sectionIdentifiers.count), sections = \(snapshot.sectionIdentifiers)")
            
            // CRITICAL: indexPath.section must correspond to a valid genre index
            // If indexPath.section >= genres.count, this means the collection view
            // is asking for more sections than we have genres - this is a bug!
            guard indexPath.section >= 0, indexPath.section < self.genres.count else {
                print("[ERROR] SupplementaryView: indexPath.section out of bounds: section=\(indexPath.section), genres.count=\(self.genres.count)")
                return
            }
            
            // Get the genre for this section - section index = genre index
            let genre = self.genres[indexPath.section]
            let labelTag = 1001
            if let existing = supplementaryView.viewWithTag(labelTag) as? UILabel {
                existing.text = genre.name
            } else {
                let label = UILabel(frame: supplementaryView.bounds)
                label.tag = labelTag
                label.translatesAutoresizingMaskIntoConstraints = false
                label.font = .systemFont(ofSize: 22, weight: .bold)
                label.textColor = .white
                label.text = genre.name
                label.accessibilityLabel = "Genre: \(genre.name)"
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
            supplementaryView.accessibilityLabel = "Genre Header"
        }

        // Cell registration for "listing" items
        let listingRegistration = UICollectionView.CellRegistration<HighlightCollectionViewCell, Listing> { cell, indexPath, listing in
            // Configure the visual appearance of each listing cell
            cell.contentView.layer.cornerRadius = 8
            cell.contentView.layer.masksToBounds = true
            cell.contentView.backgroundColor = listing.artworkColor

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

            // Set accessibility label to include the show name (which includes genre)
            // e.g., "Listing: 10:00 AM – Horror Show 3"
            cell.accessibilityLabel = "Listing: \(listing.title)"
            cell.accessibilityTraits = .button
        }

        epgDataSource = UICollectionViewDiffableDataSource<Genre, Listing>(
            collectionView: epgCollectionView
        ) { collectionView, indexPath, listing in
            return collectionView.dequeueConfiguredReusableCell(
                using: listingRegistration,
                for: indexPath,
                item: listing
            )
        }

        epgDataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }
            return collectionView.dequeueConfiguredReusableSupplementary(
                using: headerRegistration,
                for: indexPath
            )
        }

        epgCollectionView.delegate = self
    }

    // MARK: – Layout Definitions

    private func createChannelSection(forSection sectionIndex: Int, in environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        // 1. Item size: fixed 200×120
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(200), heightDimension: .absolute(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)

        // 2. Group: horizontal group showing 3 items side by side
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.9), heightDimension: .absolute(128))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: Array(repeating: item, count: 3) // **replaced deprecated initializer**
        )

        // 3. Section: a group, orthogonally scrolling
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 8

        // 4. Channel header
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(50))
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [sectionHeader]
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0)
        return section
    }

    private func createCategoryListSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(60))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(68))
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: groupSize,
            subitems: [item] // **replaced deprecated initializer**
        )

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
        return section
    }

    // MARK: – Initial Snapshot Population

    private func performInitialSnapshots() {
        // Create an empty snapshot for the EPG collection view
        // Each GENRE becomes a "section" in the collection view (8 sections total)
        // Initially, each section has no items (empty listings array)
        var snapshot = NSDiffableDataSourceSnapshot<Genre, Listing>()
        
        // Add each genre as a section (only once per genre)
        for genre in genres {
            snapshot.appendSections([genre])  // Genre becomes a section
            snapshot.appendItems([], toSection: genre)  // No listings yet
        }
        
        // Validate the snapshot before applying
        let expectedSectionCount = genres.count  // Should be 8 genres, not 80 channels
        let actualSectionCount = snapshot.sectionIdentifiers.count
        if expectedSectionCount != actualSectionCount {
            print("[ERROR] Snapshot section count mismatch: expected=\(expectedSectionCount), actual=\(actualSectionCount)")
        }
        
        epgDataSource.apply(snapshot, animatingDifferences: false)
        print("[DEBUG] performInitialSnapshots: snapshot section count = \(snapshot.sectionIdentifiers.count), genres.count = \(genres.count)")
        
        // Verify the data source has the correct number of sections
        let dataSourceSectionCount = epgDataSource.snapshot().sectionIdentifiers.count
        if dataSourceSectionCount != expectedSectionCount {
            print("[ERROR] DataSource section count mismatch after apply: expected=\(expectedSectionCount), actual=\(dataSourceSectionCount)")
        }
    }

    // MARK: – Simulated Async Loading

    private func simulateAsyncLoadingForAllChannels() {
        print("[DEBUG] 🚀 Starting async loading for \(channels.count) channels across \(genres.count) genres")
        
        // Log the channel distribution for debugging
        for genre in genres {
            let genreChannels = channels.filter { $0.genre == genre }
            print("[DEBUG] Genre '\(genre.name)': \(genreChannels.count) channels")
        }
        
        // Schedule async loading for every channel
        // Each channel gets a slightly staggered delay to simulate real-world async behavior
        for (index, channel) in channels.enumerated() {
            let channelID = channel.id
            let delay = simulatedDelaySeconds + Double(index) * 0.05
            print("[DEBUG] Scheduling channel \(index): '\(channel.name)' (Genre: \(channel.genre.name)) with delay \(delay)s")
            
            DispatchQueue.global(qos: .background).asyncAfter(
                deadline: .now() + delay
            ) {
                // This calls fetchListings for each channel after a delay
                // The delay increases by 0.05 seconds for each subsequent channel
                self.fetchListings(forChannelID: channelID)
            }
        }
    }

    private func fetchListings(forChannelID channelID: UUID) {
        print("[DEBUG] Starting async fetch for channel \(channelID). Sleeping for \(simulatedDelaySeconds)s…")
        Thread.sleep(forTimeInterval: simulatedDelaySeconds)

        // Find which channel this UUID corresponds to
        guard let sectionIndex = channelIndexLookup[channelID] else {
            print("[ERROR] Channel ID \(channelID) not found.")
            return
        }
        let channel = channels[sectionIndex]
        print("[DEBUG] fetchListings: Populating listings for channel at sectionIndex=\(sectionIndex), channel.name=\(channel.name), genre=\(channel.genre.name)")

        // Generate fake listings for this channel
        // Each listing has a time slot and show name based on the channel's genre
        var newListings: [Listing] = []
        for idx in 1...listingsPerChannel {
            let totalMinutes = (idx - 1) * 30  // 30-minute time slots
            let hour = (totalMinutes / 60) % 24
            let minute = totalMinutes % 60
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let date = Calendar.current.date(
                bySettingHour: hour, minute: minute, second: 0, of: Date()
            ) ?? Date()
            let timeString = formatter.string(from: date)
            // Show name includes the channel name and genre (e.g., "10:00 AM – Horror Channel 1: Horror Show 3")
            let showName = "\(channel.name): \(channel.genre.name) Show \(idx)"
            let title = "\(timeString) – \(showName)"
            let listing = Listing(title: title)
            newListings.append(listing)
        }

        // Update the channel's listings in our data model
        channels[sectionIndex].listings = newListings

        // FIXED: Use serial queue directly, then dispatch to main for UI updates
        // This ensures all snapshot operations happen atomically
        snapshotUpdateQueue.async {
            // Get the current snapshot from the data source on main thread
            DispatchQueue.main.sync {
                let currentSnapshot = self.epgDataSource.snapshot()
                var updatedSnapshot = currentSnapshot
                let genreSection = channel.genre  // ✅ FIXED: Use genre as section, not channel
                
                // Add listings to the genre section (multiple channels can add to same genre section)
                if updatedSnapshot.sectionIdentifiers.contains(genreSection) {
                    // Add new items to the existing genre section
                    // Note: We append instead of replacing since multiple channels contribute to same genre
                    updatedSnapshot.appendItems(newListings, toSection: genreSection)
                    
                    // Apply the updated snapshot to refresh the UI on main thread
                    self.epgDataSource.apply(updatedSnapshot, animatingDifferences: true) {
                        print("[DEBUG] ✅ Successfully loaded \(newListings.count) listings for \(channel.name) in genre \(genreSection.name) (section index: \(sectionIndex)). Genre section now has \(updatedSnapshot.itemIdentifiers(inSection: genreSection).count) total listings")
                    }
                } else {
                    print("[ERROR] ❌ Genre section \(genreSection.name) not found in snapshot. Available sections: \(updatedSnapshot.sectionIdentifiers.map { $0.name })")
                }
            }
        }
    }

    // MARK: – Focus & Category Highlighting

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        guard let nextFocused = context.nextFocusedView else { return }

        if nextFocused.isDescendant(of: headerCategoryCollectionView) {
            // Focused the top header—no sync needed here.
        }
        else if nextFocused.isDescendant(of: epgCollectionView) {
            // Locate containing cell, then highlight that genre on the left.
            if let cell = nextFocused.containingCollectionViewCell(),
               let indexPath = epgCollectionView.indexPath(for: cell) {
                // DEFENSIVE: Check bounds before accessing genres array
                guard indexPath.section >= 0, indexPath.section < genres.count else {
                    print("[ERROR] Focus: indexPath.section out of bounds: section=\(indexPath.section), genres.count=\(genres.count)")
                    return
                }
                let focusedGenre = genres[indexPath.section]
                print("[DEBUG] Focus: Accessing genre[\(indexPath.section)] of \(genres.count)")
                highlightCategory(for: focusedGenre)
            }
            else if let header = nextFocused as? UICollectionReusableView {
                let section = header.tag
                // DEFENSIVE: Check bounds before accessing genres array
                guard section >= 0, section < genres.count else {
                    print("[ERROR] Focus: header.tag out of bounds: tag=\(section), genres.count=\(genres.count)")
                    return
                }
                let focusedGenre = genres[section]
                print("[DEBUG] Focus: Accessing genre[\(section)] of \(genres.count)")
                highlightCategory(for: focusedGenre)
            }
        }
        else if nextFocused.isDescendant(of: categoriesCollectionView) {
            // Nothing special—user can move focus back to the left column normally.
        }
    }

    private func highlightCategory(for genre: Genre) {
        // DEFENSIVE: Check bounds before accessing genres array
        guard let index = genres.firstIndex(of: genre), index >= 0, index < genres.count else {
            print("[ERROR] highlightCategory: genre not found or index out of bounds. index=\(String(describing: genres.firstIndex(of: genre))), genres.count=\(genres.count)")
            return
        }
        let indexPath = IndexPath(item: index, section: 0)
        // DEFENSIVE: Double-check indexPath is valid
        guard indexPath.section == 0, indexPath.item >= 0, indexPath.item < genres.count else {
            print("[ERROR] highlightCategory: indexPath out of bounds. item=\(indexPath.item), genres.count=\(genres.count)")
            return
        }
        print("[DEBUG] highlightCategory: Selecting item \(indexPath.item) in genres.count=\(genres.count)")
        categoriesCollectionView.selectItem(
            at: indexPath,
            animated: true,
            scrollPosition: .centeredVertically
        )
        print("[DEBUG] Highlighting genre '\(genre.name)' at index \(index).")
    }
}

// MARK: – UICollectionViewDataSourcePrefetching

extension ViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        print("[DEBUG] Prefetching items at \(indexPaths)")
    }
}

// MARK: – UICollectionViewDelegate (Category Taps)

extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == categoriesCollectionView || collectionView == headerCategoryCollectionView {
            guard indexPath.item >= 0, indexPath.item < genres.count else {
                print("[ERROR] didSelectItemAt: indexPath.item out of bounds: item=\(indexPath.item), genres.count=\(genres.count)")
                return
            }
            let selectedGenre = genres[indexPath.item]
            
            // Find the section index for this genre (should match the genre index)
            guard let genreSectionIndex = genres.firstIndex(of: selectedGenre),
                  genreSectionIndex >= 0, genreSectionIndex < genres.count else {
                print("[ERROR] didSelectItemAt: Genre \(selectedGenre.name) not found or index out of bounds.")
                return
            }
            
            // Check if that genre section has any loaded listings
            let currentSnapshot = epgDataSource.snapshot()
            let listingCount = currentSnapshot.itemIdentifiers(inSection: selectedGenre).count
            print("[DEBUG] didSelectItemAt: Genre '\(selectedGenre.name)' section has \(listingCount) listings")
            
            if listingCount > 0 {
                // Safe to scroll to the first item in the genre section
                let targetIndexPath = IndexPath(item: 0, section: genreSectionIndex)
                epgCollectionView.scrollToItem(at: targetIndexPath, at: .top, animated: true)
            } else {
                // No listings yet: scroll section header into view instead
                let headerIndexPath = IndexPath(item: 0, section: genreSectionIndex)
                if let headerAttr = epgCollectionView.layoutAttributesForSupplementaryElement(
                    ofKind: UICollectionView.elementKindSectionHeader,
                    at: headerIndexPath
                ) {
                    epgCollectionView.scrollRectToVisible(headerAttr.frame, animated: true)
                } else {
                    print("[ERROR] didSelectItemAt: No header attributes for genre section \(genreSectionIndex)")
                }
            }
            print("[DEBUG] Genre '\(selectedGenre.name)' tapped—scrolling to section \(genreSectionIndex).")
        }
    }
}

// MARK: – UIView utility for finding containing collection view cell
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
