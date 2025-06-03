import UIKit
import SwiftUI

// MARK: - Coordinator for UIKit <-> SwiftUI Communication
class EPGCoordinator: ObservableObject {
    @Published var selectedGenre: Genre?
    @Published var genres: [Genre] = []
    @Published var channels: [Channel] = []
    
    func updateData(genres: [Genre], channels: [Channel]) {
        self.genres = genres
        self.channels = channels
    }
    
    func selectGenre(_ genre: Genre) {
        selectedGenre = genre
    }
}

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

// MARK: - SwiftUI EPG View
struct EPGView: View {
    @ObservedObject var coordinator: EPGCoordinator
    @State private var focusedGenre: Genre?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(coordinator.genres, id: \.id) { genre in
                        GenreSection(genre: genre, channels: channelsForGenre(genre))
                            .id(genre.id)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .accessibilityLabel("TV Guide")
            .accessibilityHint("Browse shows by category. Swipe to view different time slots.")
            .onChange(of: coordinator.selectedGenre) { selectedGenre in
                if let selectedGenre = selectedGenre {
                    scrollToGenre(selectedGenre, proxy: proxy)
                }
            }
        }
    }
    
    private func channelsForGenre(_ genre: Genre) -> [Channel] {
        return coordinator.channels.filter { $0.genre == genre }
    }
    
    private func scrollToGenre(_ genre: Genre, proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.5)) {
            proxy.scrollTo(genre.id, anchor: .top)
        }
    }
}

struct GenreSection: View {
    let genre: Genre
    let channels: [Channel]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Genre Header
            Text(genre.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .accessibilityLabel("Genre: \(genre.name)")
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            
            // Channel Listings
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(allListingsForGenre(), id: \.id) { listing in
                        ListingCard(listing: listing)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func allListingsForGenre() -> [Listing] {
        return channels.flatMap { $0.listings }
    }
}

struct ListingCard: View {
    let listing: Listing
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack {
            Text(listing.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(4)
        }
        .frame(width: 200, height: 120)
        .background(Color(listing.artworkColor))
        .cornerRadius(8)
        .focused($isFocused)
        .accessibilityLabel("Show: \(listing.title)")
        .accessibilityHint("Double tap to select this show")
        .accessibilityAddTraits([.isButton])
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.green : Color.clear, lineWidth: 4)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

final class ViewController: UIViewController {
    // MARK: - Accessibility Container Support
    override var accessibilityElements: [Any]? {
        get {
            // Return the sidebar cells as the primary accessibility elements
            var elements: [Any] = []
            
            // Add category collection view cells
            for index in 0..<genres.count {
                let indexPath = IndexPath(item: index, section: 0)
                if let cell = categoriesCollectionView.cellForItem(at: indexPath) {
                    elements.append(cell)
                }
            }
            
            // Add the EPG collection view as a single element
            elements.append(epgHostingController)
            
            return elements
        }
        set {
            // Do nothing - we manage this dynamically
        }
    }

    // MARK: – Configurable Constants
    private let genreNames: [String] = ["Horror", "Comedy", "Drama", "Sports", "Kids", "Documentary", "News", "Music"]
    private let channelsPerGenre: Int = 10
    private let listingsPerChannel: Int = 20
    private let simulatedDelaySeconds: TimeInterval = 1.0
    private let categoryColumnWidth: CGFloat = 250

    // MARK: - Coordinator
    private let coordinator = EPGCoordinator()

    // MARK: – UI Elements
    private lazy var categoriesCollectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ -> NSCollectionLayoutSection? in
            return self.createCategoryListSection()
        }
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .black
        cv.remembersLastFocusedIndexPath = true
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.accessibilityIdentifier = "CategoriesCollectionView"
        cv.accessibilityLabel = "Categories"
        cv.accessibilityHint = "Swipe up or down to browse categories. Select a category to view its shows."
        cv.accessibilityTraits = .adjustable
        cv.shouldGroupAccessibilityChildren = false
        cv.isAccessibilityElement = false
        return cv
    }()

    // SwiftUI EPG View
    private lazy var epgHostingController: UIHostingController<EPGView> = {
        let epgView = EPGView(coordinator: coordinator)
        let hostingController = UIHostingController(rootView: epgView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .black
        return hostingController
    }()

    // MARK: – Diffable Data Sources
    private enum CategorySection { case main }
    private var categoryDataSource: UICollectionViewDiffableDataSource<CategorySection, Genre>!

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
        view.shouldGroupAccessibilityChildren = false
        view.isAccessibilityElement = false

        configureGenresAndChannels()
        configureCategoryCollectionView()
        configureEPGView()
        performInitialSnapshots()
        simulateAsyncLoadingForAllChannels()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        epgHostingController.view.layoutIfNeeded()
        
        // Refresh accessibility elements after layout
        DispatchQueue.main.async { [weak self] in
            self?.refreshAccessibilityElements()
        }
    }

    private func refreshAccessibilityElements() {
        // Force VoiceOver to re-evaluate accessibility elements
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }

    // MARK: – SwiftUI EPG View Setup
    private func configureEPGView() {
        // Add as child view controller
        addChild(epgHostingController)
        view.addSubview(epgHostingController.view)
        epgHostingController.didMove(toParent: self)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            epgHostingController.view.leadingAnchor.constraint(equalTo: categoriesCollectionView.trailingAnchor),
            epgHostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            epgHostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            epgHostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
        
        // Update coordinator with initial data
        coordinator.updateData(genres: genres, channels: channels)
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
            cell.accessibilityLabel = "\(genre.name) category"
            cell.accessibilityHint = "Select to view \(genre.name) shows"
            cell.accessibilityTraits = .button
            cell.isAccessibilityElement = true
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

    // MARK: – Layout Definitions

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
        print("[DEBUG] performInitialSnapshots: Initialized with \(genres.count) genres and \(channels.count) channels")
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

        // Update SwiftUI view on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Update coordinator with new data
            self.coordinator.updateData(genres: self.genres, channels: self.channels)
            print("[DEBUG] ✅ Successfully loaded \(newListings.count) listings for \(channel.name) in genre \(channel.genre.name)")
        }
    }

    // MARK: – Focus & Category Highlighting

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        guard let nextFocused = context.nextFocusedView else { return }

        if nextFocused.isDescendant(of: epgHostingController.view) {
            // SwiftUI EPG view is focused - for now just log
            print("[DEBUG] Focus: SwiftUI EPG view focused")
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

// MARK: – UICollectionViewDelegate (Category Taps)

extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == categoriesCollectionView {
            guard indexPath.item >= 0, indexPath.item < genres.count else {
                print("[ERROR] didSelectItemAt: indexPath.item out of bounds: item=\(indexPath.item), genres.count=\(genres.count)")
                return
            }
            let selectedGenre = genres[indexPath.item]
            
            // Notify SwiftUI view of genre selection via coordinator
            coordinator.selectGenre(selectedGenre)
            print("[DEBUG] Genre '\(selectedGenre.name)' selected - notified SwiftUI EPG via coordinator.")
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
