import UIKit
import SwiftUI
import Combine
import os

// MARK: - Focus Diagnostics (Strategy A)

/// Centralised, opt‑in focus & VoiceOver telemetry.
/// Call `FocusLogger.shared.start()` once at app launch.
final class FocusLogger {
    static let shared = FocusLogger()

    /// Points‑of‑interest log visible in Instruments.
    let log: OSLog = .init(subsystem: Bundle.main.bundleIdentifier ?? "InfinityBug",
                           category: "Focus")

    private var cancellables: Set<AnyCancellable> = []
    private init() {}

    /// Starts logging VoiceOver status and element focus hops.
    func start() {
        guard cancellables.isEmpty else { return }     // idempotent

        // 1️⃣  VoiceOver enabled / disabled
        NotificationCenter.default.publisher(
            for: UIAccessibility.voiceOverStatusDidChangeNotification
        )
        .sink { _ in
            let enabled = UIAccessibility.isVoiceOverRunning
            os_signpost(.event, log: self.log,
                        name: "VOStatus", "%{public}s", enabled.description)
            print("🟣 VoiceOver \(enabled ? "ENABLED" : "DISABLED")")
        }
        .store(in: &cancellables)

        // 2️⃣  Element focus hops
        NotificationCenter.default.publisher(
            for: UIAccessibility.elementFocusedNotification
        )
        .sink { [weak self] note in
            guard
                let self,
                let element = note.userInfo?[UIAccessibility.focusedElementUserInfoKey] as? NSObject
            else { return }

            let description = Self.describe(element)
            os_signpost(.event, log: self.log, name: "AXFocus", "%{public}s", description)
            print("🟢 AX → \(description)")
        }
        .store(in: &cancellables)
    }

    /// Human‑readable element summary for logs.
    static func describe(_ element: NSObject) -> String {
        if let view = element as? UIView {
            return "\(type(of: view))(id: \(view.accessibilityIdentifier ?? "nil"), " +
                   "label: \(view.accessibilityLabel ?? "nil"))"
        } else {
            return String(describing: element)
        }
    }
}

// MARK: - Custom Hosting Controller for Focus Management
class FocusableHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Start Strategy A diagnostics
        FocusLogger.shared.start()
        // Configure the view to be focusable
        view.isUserInteractionEnabled = true
        view.isAccessibilityElement = true
        view.accessibilityTraits = .none
        print("[FOCUS] FocusableHostingController viewDidLoad")
        print("[FOCUS] View isUserInteractionEnabled: \(view.isUserInteractionEnabled)")
    }
    
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        print("[FOCUS] FocusableHostingController preferredFocusEnvironments called")
        
        // Always prefer our own view first to ensure we can receive focus
        let environments: [UIFocusEnvironment] = [self.view]
        print("[FOCUS] Preferred environments count: \(environments.count)")
        return environments
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        if context.nextFocusedView === self.view {
            print("[FOCUS] SwiftUI EPG hosting controller view gained focus")
        } else if context.previouslyFocusedView === self.view {
            print("[FOCUS] SwiftUI EPG hosting controller view lost focus")
        }
    }
}

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

// MARK: - Focus Environment for SwiftUI-UIKit Integration
struct FocusableEPGView: View {
    @ObservedObject var coordinator: EPGCoordinator
    @FocusState private var focusedListing: UUID?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(coordinator.genres, id: \.id) { genre in
                        FocusableGenreSection(
                            genre: genre,
                            channels: channelsForGenre(genre),
                            focusedListing: $focusedListing
                        )
                        .id(genre.id)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .accessibilityLabel("TV Guide")
            .accessibilityHint("Browse shows by category. Swipe to view different time slots.")
            .onAppear {
                print("[FOCUS] SwiftUI EPG view appeared")
            }
            .onChange(of: coordinator.selectedGenre) { oldValue, newSelectedGenre in
                print("[FOCUS] SwiftUI: coordinator.selectedGenre changed to: \(newSelectedGenre?.name ?? "nil")")
                if let genre = newSelectedGenre {
                    scrollToGenre(genre, proxy: proxy)
                    // Focus the first listing immediately if available, otherwise wait for data
                    focusFirstListing(in: genre)
                }
            }
            .onChange(of: coordinator.channels) { oldValue, newChannels in
                print("[FOCUS] SwiftUI: coordinator.channels updated")
                // If a genre is selected and we don't have focus yet, try to focus the first item
                if focusedListing == nil, let currentSelectedGenre = coordinator.selectedGenre {
                    let listingsForSelectedGenre = channelsForGenre(currentSelectedGenre)
                                                    .flatMap { $0.listings }
                    if !listingsForSelectedGenre.isEmpty {
                        print("[FOCUS] SwiftUI: Attempting to focus first listing for \(currentSelectedGenre.name)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                             focusFirstListing(in: currentSelectedGenre)
                        }
                    }
                }
            }
        }
    }
    
    private func channelsForGenre(_ genre: Genre) -> [Channel] {
        return coordinator.channels.filter { $0.genre == genre }
    }
    
    private func scrollToGenre(_ genre: Genre, proxy: ScrollViewProxy) {
        print("[FOCUS] SwiftUI: Scrolling to genre: \(genre.name)")
        withAnimation(.easeInOut(duration: 0.5)) {
            proxy.scrollTo(genre.id, anchor: .top)
        }
    }
    
    private func focusFirstListing(in genre: Genre) {
        let channelsForGenre = channelsForGenre(genre)
        guard let firstChannel = channelsForGenre.first,
              let firstListing = firstChannel.listings.first else {
            print("[FOCUS] SwiftUI: No listings found for genre \(genre.name)")
            return
        }
        
        print("[FOCUS] SwiftUI: Focusing first listing: \(firstListing.title)")
        focusedListing = firstListing.id
    }
}

struct FocusableGenreSection: View {
    let genre: Genre
    let channels: [Channel]
    @FocusState.Binding var focusedListing: UUID?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Genre Header - not focusable
            Text(genre.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .accessibilityLabel("Genre: \(genre.name)")
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            
            // Channel Listings - each cell is focusable
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(allListingsForGenre(), id: \.id) { (listing: Listing) in
                        let isFocused = focusedListing == listing.id
                        FocusableListingCard(listing: listing, isFocused: isFocused)
                            .focused($focusedListing, equals: listing.id)
                            .onAppear {
                                if isFocused {
                                    print("[FOCUS] SwiftUI: Listing appeared and is focused: \(listing.title)")
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        // Remove focusable from container
        .onAppear {
            print("[FOCUS] SwiftUI: Genre section appeared: \(genre.name)")
        }
    }
    
    private func allListingsForGenre() -> [Listing] {
        return channels.flatMap { $0.listings }
    }
}

struct FocusableListingCard: View {
    let listing: Listing
    let isFocused: Bool
    
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
        .accessibilityLabel("Show: \(listing.title)")
        .accessibilityHint("Double tap to select this show")
        .accessibilityAddTraits([.isButton])
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.green : Color.clear, lineWidth: 4)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .focusable(true) // Ensure each card is focusable
        .onAppear {
            if isFocused {
                print("[FOCUS] SwiftUI: Listing card appeared and is focused: \(listing.title)")
            }
        }
    }
}

final class ViewController: UIViewController {
    /// Ordered list presented when VoiceOver runs "Read Screen After Delay"
    private var customAccessibilityElements: [UIAccessibilityElement] = []
    /// Ensures "can focus items" message prints only once
    private var didLogCanFocusOnce = false

    // MARK: - Accessibility Container Support
    override var accessibilityElements: [Any]? {
        get { rebuildAccessibilityElements(); return customAccessibilityElements }
        set { /* ignore – managed internally */ }
    }

    /// Constructs virtual UIAccessibilityElements so VoiceOver's
    /// "Read Screen After Delay" proceeds top‑to‑bottom through all
    /// sidebar categories **before** the EPG.
    private func rebuildAccessibilityElements() {
        customAccessibilityElements.removeAll()

        // 1️⃣  Sidebar genre buttons
        for (idx, genre) in genres.enumerated() {
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel  = genre.name
            element.accessibilityHint   = "Category"
            element.accessibilityTraits = [.button]

            // Try real cell frame if visible, else fallback to row estimate
            if let cell = categoriesCollectionView.cellForItem(at: IndexPath(item: idx, section: 0)) {
                element.accessibilityFrameInContainerSpace = cell.frame
            } else {
                // Approximate: same width, 68‑pt rows
                element.accessibilityFrameInContainerSpace = CGRect(
                    x: 0,
                    y: CGFloat(idx) * 68,
                    width: categoryColumnWidth,
                    height: 68
                )
            }
            customAccessibilityElements.append(element)
        }

        // 2️⃣  Entire EPG as one element (VoiceOver will descend into it later)
        let epgElement = UIAccessibilityElement(accessibilityContainer: self)
        epgElement.accessibilityLabel  = "TV Guide"
        epgElement.accessibilityTraits = []
        epgElement.accessibilityFrameInContainerSpace = epgHostingController.view.frame
        customAccessibilityElements.append(epgElement)
    }

    // MARK: – Configurable Constants
    private let genreNames: [String] = ["Horror", "Comedy", "Drama", "Sports", "Kids", "Documentary", "News", "Music"]
    private let channelsPerGenre: Int = 10
    private let listingsPerChannel: Int = 20
    private let simulatedDelaySeconds: TimeInterval = 1.0
    private let categoryColumnWidth: CGFloat = 250
    
    // MARK: - Async Request Control
    public static var spoofAsyncRequests: Bool = false
    
    public func setSpoofAsyncRequests(_ enabled: Bool) {
        Self.spoofAsyncRequests = enabled
        print("[DEBUG] SpoofAsyncRequests set to: \(enabled)")
    }

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
    private lazy var epgHostingController: FocusableHostingController<FocusableEPGView> = {
        let epgView = FocusableEPGView(coordinator: coordinator)
        let hostingController = FocusableHostingController(rootView: epgView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .black
        
        // Enable focus for tvOS navigation
        hostingController.view.isUserInteractionEnabled = true
        
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
    
    // Thread-safe access queue for shared data
    private let dataAccessQueue = DispatchQueue(label: "com.epg.data.access", qos: .userInitiated, attributes: .concurrent)

    // Add focus guide for UIKit/SwiftUI handoff
    private var focusGuide: UIFocusGuide!

    // MARK: - Thread-Safe Data Access
    private func getChannel(byID channelID: UUID) -> (channel: Channel, index: Int)? {
        return dataAccessQueue.sync {
            guard let index = channelIndexLookup[channelID],
                  index < channels.count else {
                return nil
            }
            return (channels[index], index)
        }
    }
    
    private func updateChannelListings(at index: Int, with listings: [Listing]) {
        dataAccessQueue.sync(flags: .barrier) {
            guard index < channels.count else { return }
            channels[index].listings = listings
        }
    }
    
    private func getAllChannels() -> [Channel] {
        return dataAccessQueue.sync {
            return channels
        }
    }
    
    private func getAllGenres() -> [Genre] {
        return dataAccessQueue.sync {
            return genres
        }
    }

    // MARK: – Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.accessibilityLabel = "EPG Main View"
        view.shouldGroupAccessibilityChildren = false
        view.isAccessibilityElement = false

        // Check for test mode launch argument
        if ProcessInfo.processInfo.arguments.contains("-DisableAsyncRequestSpoofing") {
            ViewController.spoofAsyncRequests = false
        }

        if ProcessInfo.processInfo.arguments.contains("-EnableAsyncRequestSpoofing") {
            ViewController.spoofAsyncRequests = true
        }

        configureGenresAndChannels()
        configureCategoryCollectionView()
        configureEPGView()
        performInitialSnapshots()
        
        // DELAY heavy background operations to prevent app launch failures
        print("[DEBUG] App launch complete - scheduling background data loading in 1 second...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("[DEBUG] Starting delayed background data loading...")
            self.simulateAsyncLoadingForAllChannels()
        }
        
        // Configure focus guide for cell-to-cell navigation
        focusGuide = UIFocusGuide()
        focusGuide.isEnabled = true
        view.addLayoutGuide(focusGuide)
        
        // Position focus guide between cells
        NSLayoutConstraint.activate([
            focusGuide.leadingAnchor.constraint(equalTo: categoriesCollectionView.trailingAnchor),
            focusGuide.trailingAnchor.constraint(equalTo: epgHostingController.view.leadingAnchor),
            focusGuide.topAnchor.constraint(equalTo: view.topAnchor),
            focusGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Set accessibility identifiers for testing
        categoriesCollectionView.accessibilityIdentifier = "CategoriesCollectionView"
        epgHostingController.view.accessibilityIdentifier = "EPGView"
    }

    // MARK: - UIScene Lifecycle Support
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure we're properly configured for the scene
        if let windowScene = view.window?.windowScene {
            windowScene.delegate = self
        }
        
        // Set initial focus on first category cell
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let firstCell = self.categoriesCollectionView.cellForItem(at: IndexPath(item: 0, section: 0)) {
                firstCell.setNeedsFocusUpdate()
                firstCell.updateFocusIfNeeded()
                // Force focus system to update
                self.setNeedsFocusUpdate()
                self.updateFocusIfNeeded()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Ensure initial focus is set after view appears
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let firstCell = self.categoriesCollectionView.cellForItem(at: IndexPath(item: 0, section: 0)) {
                firstCell.setNeedsFocusUpdate()
                firstCell.updateFocusIfNeeded()
                // Force focus system to update
                self.setNeedsFocusUpdate()
                self.updateFocusIfNeeded()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        epgHostingController.view.layoutIfNeeded()

        // Rebuild accessibility elements after layout
        rebuildAccessibilityElements()
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
        
        // Ensure the hosting controller view can receive focus
        epgHostingController.view.isUserInteractionEnabled = true
        epgHostingController.view.backgroundColor = .black
        
        // Configure the view for focus
        epgHostingController.view.isAccessibilityElement = true
        epgHostingController.view.accessibilityLabel = "TV Guide"
        epgHostingController.view.accessibilityTraits = .none
        
        print("[FOCUS] Configuring EPG view...")
        print("[FOCUS] EPG view isUserInteractionEnabled: \(epgHostingController.view.isUserInteractionEnabled)")
        
        // Set up constraints
        NSLayoutConstraint.activate([
            epgHostingController.view.leadingAnchor.constraint(equalTo: categoriesCollectionView.trailingAnchor),
            epgHostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            epgHostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            epgHostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        print("[FOCUS] EPG view constraints configured")
    }

    // MARK: - Focus Helper Methods
    private func attemptFocusTransferToEPG() {
        print("[FOCUS] Attempting manual focus transfer to EPG...")
        
        // Force the hosting controller to become the preferred focus environment
        focusGuide.preferredFocusEnvironments = [epgHostingController]
        
        // Use the focus guide to transfer focus
        print("[FOCUS] Using focus guide to transfer focus...")
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        
        // Also try direct focus on the hosting controller
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            print("[FOCUS] Attempting direct focus on EPG hosting controller...")
            self.epgHostingController.setNeedsFocusUpdate()
            self.epgHostingController.updateFocusIfNeeded()
            
            // Force focus system to update
            self.setNeedsFocusUpdate()
            self.updateFocusIfNeeded()
            
            // Verify focus state after attempt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                let currentFocus = UIFocusSystem.focusSystem(for: self.view)?.focusedItem
                print("[FOCUS] Focus transfer attempt completed")
                print("[FOCUS] Current focused item: \(currentFocus.map { "\(type(of: $0))" } ?? "none")")
                
                if let currentFocus = currentFocus {
                    if let focusView = currentFocus as? UIView {
                        let isInEPG = focusView.isDescendant(of: self.epgHostingController.view)
                        print("[FOCUS] Is focused item in EPG view? \(isInEPG)")
                        
                        if !isInEPG {
                            print("[FOCUS] Focus transfer failed, trying alternative approach...")
                            // Try setting the EPG as preferred focus environment
                            self.epgHostingController.view.setNeedsFocusUpdate()
                            self.epgHostingController.view.updateFocusIfNeeded()
                            // Force focus system to update
                            self.setNeedsFocusUpdate()
                            self.updateFocusIfNeeded()
                        }
                    }
                }
            }
        }
    }
    
    private func transferFocusToEPGFirstItem() {
        print("[FOCUS] Transferring focus to EPG first item...")
        
        // First, ensure the EPG view is ready to receive focus
        epgHostingController.view.isUserInteractionEnabled = true
        
        // Configure focus guide for the transition
        focusGuide.isEnabled = true
        focusGuide.preferredFocusEnvironments = [epgHostingController]
        
        // Force focus update on the EPG view
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // First update the focus guide
            self.setNeedsFocusUpdate()
            self.updateFocusIfNeeded()
            
            // Then force focus on the EPG
            self.epgHostingController.setNeedsFocusUpdate()
            self.epgHostingController.updateFocusIfNeeded()
            
            // Force focus system to update
            self.setNeedsFocusUpdate()
            self.updateFocusIfNeeded()
            
            // Verify focus state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                let currentFocus = UIFocusSystem.focusSystem(for: self.view)?.focusedItem
                if let focusView = currentFocus as? UIView {
                    let isInEPG = focusView.isDescendant(of: self.epgHostingController.view)
                    print("[FOCUS] Focus transfer result - In EPG: \(isInEPG)")
                    
                    if !isInEPG {
                        print("[FOCUS] Focus transfer failed, trying alternative approach...")
                        // Try direct focus on the first listing
                        if let firstGenre = self.coordinator.genres.first {
                            self.coordinator.selectGenre(firstGenre)
                            
                            // Force another focus update after genre selection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                                guard let self = self else { return }
                                // Try to force focus on the EPG view again
                                self.focusGuide.preferredFocusEnvironments = [self.epgHostingController]
                                self.setNeedsFocusUpdate()
                                self.updateFocusIfNeeded()
                                
                                // Also try direct focus on the EPG
                                self.epgHostingController.setNeedsFocusUpdate()
                                self.epgHostingController.updateFocusIfNeeded()
                                
                                // Force focus system to update
                                self.setNeedsFocusUpdate()
                                self.updateFocusIfNeeded()
                                
                                // If still not focused, try one more time with a longer delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                                    guard let self = self else { return }
                                    if let currentFocus = UIFocusSystem.focusSystem(for: self.view)?.focusedItem as? UIView,
                                       !currentFocus.isDescendant(of: self.epgHostingController.view) {
                                        print("[FOCUS] Final attempt to transfer focus...")
                                        self.focusGuide.preferredFocusEnvironments = [self.epgHostingController]
                                        self.setNeedsFocusUpdate()
                                        self.updateFocusIfNeeded()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        let previousView = context.previouslyFocusedView
        let nextView = context.nextFocusedView
        
        // Log focus transitions
        if let prev = previousView, let next = nextView {
            print("[FOCUS] Focus transition: \(type(of: prev)) → \(type(of: next))")
        }
        
        // Handle focus guide activation
        if nextView == focusGuide {
            // Find the currently focused cell in categories
            if let focusedCell = context.previouslyFocusedView as? UICollectionViewCell,
               let indexPath = categoriesCollectionView.indexPath(for: focusedCell) {
                // Find the corresponding first listing in EPG
                let genre = self.coordinator.genres[indexPath.item]
                if let firstChannel = self.coordinator.channels.first(where: { $0.genre == genre }),
                   let firstListing = firstChannel.listings.first {
                    // Update focus guide to target the first listing
                    focusGuide.preferredFocusEnvironments = [epgHostingController]
                    print("[FOCUS] Focus guide activated - targeting first listing in EPG \(firstListing.title)")
                }
            }
        }
        
        // Update focus guide targeting based on current focus
        if let nextView = nextView {
            if nextView.isDescendant(of: categoriesCollectionView) {
                // When in categories, target the first listing of the focused genre
                if let cell = nextView as? UICollectionViewCell,
                   let indexPath = categoriesCollectionView.indexPath(for: cell) {
                    let genre = self.coordinator.genres[indexPath.item]
                    focusGuide.preferredFocusEnvironments = [epgHostingController]
                    print("[FOCUS] FocusGuide targeting first listing in EPG for genre: \(genre.name)")
                }
            } else if nextView.isDescendant(of: epgHostingController.view) {
                // When in EPG, target the corresponding category
                focusGuide.preferredFocusEnvironments = [categoriesCollectionView]
                print("[FOCUS] FocusGuide targeting Categories")
            }
        }
    }

    // MARK: – Setup Data Models
    private func configureGenresAndChannels() {
        // Create genres from the predefined genre names
        let newGenres = genreNames.map { Genre(name: $0) }

        // Create channels: for each genre, create channelsPerGenre number of channels
        // This creates a total of genreNames.count * channelsPerGenre channels
        // For example: 8 genres * 10 channels = 80 total channels
        var tempChannels: [Channel] = []
        var tempChannelIndexLookup: [UUID: Int] = [:]
        
        for genre in newGenres {
            for channelIdx in 0..<channelsPerGenre {
                let channelName = "\(genre.name) Channel \(channelIdx + 1)"
                let channel = Channel(name: channelName, genre: genre)
                tempChannels.append(channel)
                // Create a lookup dictionary to quickly find a channel's index by its UUID
                tempChannelIndexLookup[channel.id] = tempChannels.count - 1
            }
        }

        // Thread-safe assignment of all data at once
        dataAccessQueue.sync(flags: .barrier) {
            self.genres = newGenres
            self.channels = tempChannels
            self.channelIndexLookup = tempChannelIndexLookup
        }
        
        // Update coordinator with initial data
        coordinator.updateData(genres: getAllGenres(), channels: getAllChannels())
        print("[DEBUG] Configured \(newGenres.count) genres and \(tempChannels.count) total channels.")
        rebuildAccessibilityElements()
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
        categorySnapshot.appendItems(getAllGenres(), toSection: .main)
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
        let currentChannels = getAllChannels()
        let currentGenres = getAllGenres()
        
        print("[DEBUG] Starting async loading for \(currentChannels.count) channels across \(currentGenres.count) genres")
        
        // Log the channel distribution for debugging
        for genre in currentGenres {
            let genreChannels = currentChannels.filter { $0.genre == genre }
            print("[DEBUG] Genre '\(genre.name)': \(genreChannels.count) channels")
        }
        
        if !Self.spoofAsyncRequests {
            // Instant loading for testing
            print("[DEBUG] SpoofAsyncRequests disabled - loading all listings instantly")
            for channel in currentChannels {
                generateAndUpdateListings(for: channel)
            }
            return
        }
        
        // Process channels in smaller batches to reduce resource pressure
        let batchSize = 10
        let totalBatches = (currentChannels.count + batchSize - 1) / batchSize
        
        print("[DEBUG] Processing \(currentChannels.count) channels in \(totalBatches) batches of \(batchSize)")
        
        for batchIndex in stride(from: 0, to: currentChannels.count, by: batchSize) {
            let endIndex = min(batchIndex + batchSize, currentChannels.count)
            let batch = Array(currentChannels[batchIndex..<endIndex])
            let currentBatchNumber = (batchIndex / batchSize) + 1
            
            let batchDelay = Double(batchIndex / batchSize) * 0.5
            
            print("[DEBUG] Scheduling batch \(currentBatchNumber)/\(totalBatches) with \(batch.count) channels, delay: \(batchDelay)s")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + batchDelay) {
                print("[DEBUG] Starting batch \(currentBatchNumber)/\(totalBatches)")
                
                for (localIndex, channel) in batch.enumerated() {
                    let globalIndex = batchIndex + localIndex
                    let additionalDelay = self.simulatedDelaySeconds + Double(localIndex) * 0.05
                    
                    print("[DEBUG] Scheduling channel \(globalIndex): '\(channel.name)' (Genre: \(channel.genre.name)) with delay \(additionalDelay)s")
                    
                    DispatchQueue.global(qos: .background).asyncAfter(
                        deadline: .now() + additionalDelay
                    ) {
                        self.generateAndUpdateListings(for: channel)
                    }
                }
            }
        }
    }
    
    private func generateAndUpdateListings(for channel: Channel) {
        if Self.spoofAsyncRequests {
            print("[DEBUG] Sleeping for \(simulatedDelaySeconds)s before generating listings...")
            Thread.sleep(forTimeInterval: simulatedDelaySeconds)
        }
        
        // Thread-safe lookup of channel data
        guard let (_, sectionIndex) = getChannel(byID: channel.id) else {
            print("[ERROR] Channel ID \(channel.id) not found or index out of bounds.")
            return
        }
        
        print("[DEBUG] Generating listings for channel at sectionIndex=\(sectionIndex), channel.name=\(channel.name), genre=\(channel.genre.name)")

        // Generate fake listings for this channel
        var newListings: [Listing] = []
        for idx in 1...listingsPerChannel {
            let totalMinutes = (idx - 1) * 30
            let hour = (totalMinutes / 60) % 24
            let minute = totalMinutes % 60
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let date = Calendar.current.date(
                bySettingHour: hour, minute: minute, second: 0, of: Date()
            ) ?? Date()
            let timeString = formatter.string(from: date)
            let showName = "\(channel.name): \(channel.genre.name) Show \(idx)"
            let title = "\(timeString) – \(showName)"
            let listing = Listing(title: title)
            newListings.append(listing)
        }

        // Thread-safe update of channel's listings
        updateChannelListings(at: sectionIndex, with: newListings)

        // Update SwiftUI view on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.coordinator.updateData(genres: self.getAllGenres(), channels: self.getAllChannels())
            print("[DEBUG] ✅ Successfully loaded \(newListings.count) listings for \(channel.name) in genre \(channel.genre.name)")
        }
    }

    // MARK: – Focus & Category Highlighting

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        print("[FOCUS] preferredFocusEnvironments called")
        
        // Find the currently focused cell
        if let focusedCell = UIFocusSystem.focusSystem(for: view)?.focusedItem as? UICollectionViewCell {
            print("[FOCUS] Returning focused category cell")
            return [focusedCell]
        }
        
        // If no cell is focused, return the first cell
        if let firstCell = categoriesCollectionView.cellForItem(at: IndexPath(item: 0, section: 0)) {
            print("[FOCUS] Returning first category cell")
            return [firstCell]
        }
        
        print("[FOCUS] No cells available, returning categories collection view")
        return [categoriesCollectionView]
    }
    
    override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
        let shouldUpdate = super.shouldUpdateFocus(in: context)
        let previousView = context.previouslyFocusedView
        let nextView = context.nextFocusedView
        
        print("[FOCUS] shouldUpdateFocus called")
        print("[FOCUS] From: \(previousView.map { "\(type(of: $0))" } ?? "nil")")
        print("[FOCUS] To: \(nextView.map { "\(type(of: $0))" } ?? "nil")")
        print("[FOCUS] Should update: \(shouldUpdate)")
        
        // Allow all focus updates by default but log the decision
        return shouldUpdate
    }
    
    private func highlightCategory(for genre: Genre) {
        let currentGenres = getAllGenres()
        // DEFENSIVE: Check bounds before accessing genres array
        guard let index = currentGenres.firstIndex(of: genre), index >= 0, index < currentGenres.count else {
            print("[ERROR] highlightCategory: genre not found or index out of bounds. index=\(String(describing: currentGenres.firstIndex(of: genre))), genres.count=\(currentGenres.count)")
            return
        }
        let indexPath = IndexPath(item: index, section: 0)
        // DEFENSIVE: Double-check indexPath is valid
        guard indexPath.section == 0, indexPath.item >= 0, indexPath.item < currentGenres.count else {
            print("[ERROR] highlightCategory: indexPath out of bounds. item=\(indexPath.item), genres.count=\(currentGenres.count)")
            return
        }
        print("[DEBUG] highlightCategory: Selecting item \(indexPath.item) in genres.count=\(currentGenres.count)")
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
            let currentGenres = getAllGenres()
            guard indexPath.item >= 0, indexPath.item < currentGenres.count else { return }
            let selectedGenre = currentGenres[indexPath.item]
            
            print("[FOCUS] Genre selected: '\(selectedGenre.name)' at index \(indexPath.item)")
            
            // Update the coordinator which will trigger SwiftUI updates
            coordinator.selectGenre(selectedGenre)
            print("[FOCUS] Notified SwiftUI EPG via coordinator")
            
            // Transfer focus to EPG view and focus first item
            print("[FOCUS] Requesting focus transfer to EPG...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("[FOCUS] Triggering focus transfer...")
                self.transferFocusToEPGFirstItem()
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        // Categories sidebar – log only once on the first invocation
        if collectionView == categoriesCollectionView && indexPath.item == 0 && !didLogCanFocusOnce {
            print("[FOCUS] Categories collection view can focus items")
            didLogCanFocusOnce = true
        }
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let previousIndexPath = context.previouslyFocusedIndexPath {
            print("[FOCUS] Collection view focus moved FROM index \(previousIndexPath)")
        }
        if let nextIndexPath = context.nextFocusedIndexPath {
            print("[FOCUS] Collection view focus moved TO index \(nextIndexPath)")
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

// MARK: – Remote Press Handling
extension ViewController {
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else {
            super.pressesEnded(presses, with: event)
            return
        }
        // Determine the currently focused view
        let currentFocused = UIFocusSystem.focusSystem(for: self.view)?.focusedItem as? UIView
        switch press.type {
        case .rightArrow:
            print("[FOCUS] REMOTE RIGHT tap")
            if let focusView = currentFocused,
               focusView.isDescendant(of: categoriesCollectionView) {
                print("[FOCUS] ⮕ From sidebar – forcing focus into EPG")
                transferFocusToEPGFirstItem()
                return
            }
        case .leftArrow:
            print("[FOCUS] REMOTE LEFT tap")
            if let focusView = currentFocused,
               focusView.isDescendant(of: epgHostingController.view) {
                print("[FOCUS] ⮐ From EPG – forcing focus back to sidebar")
                focusGuide.preferredFocusEnvironments = [categoriesCollectionView]
                categoriesCollectionView.setNeedsFocusUpdate()
                categoriesCollectionView.updateFocusIfNeeded()
                return
            }
        case .upArrow:
            print("[FOCUS] REMOTE UP tap — current: \(FocusLogger.describe(currentFocused ?? UIView()))")
        case .downArrow:
            print("[FOCUS] REMOTE DOWN tap — current: \(FocusLogger.describe(currentFocused ?? UIView()))")
        case .select:
            print("[FOCUS] REMOTE SELECT tap — current: \(FocusLogger.describe(currentFocused ?? UIView()))")
        default:
            break
        }
        super.pressesEnded(presses, with: event)
    }
}

// MARK: - UISceneDelegate
extension ViewController: UISceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        windowScene.delegate = self
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Ensure focus is properly set when scene becomes active
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let firstCell = self.categoriesCollectionView.cellForItem(at: IndexPath(item: 0, section: 0)) {
                firstCell.setNeedsFocusUpdate()
                firstCell.updateFocusIfNeeded()
                // Force focus system to update
                self.setNeedsFocusUpdate()
                self.updateFocusIfNeeded()
            }
        }
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Clean up if needed
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Clean up if needed
    }
}
