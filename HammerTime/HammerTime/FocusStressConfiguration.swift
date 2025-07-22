import Foundation

// MARK: - Configuration Presets

/// Defines preset configurations for the FocusStressViewController.
public enum FocusStressPreset: CaseIterable {
    case lightExploration
    case mediumStress
    case heavyReproduction
    case edgeTesting
    case performanceBaseline
    case maxStress

    /// String representation for launch arguments and UI tests.
    /// This method avoids RawRepresentable protocol complications across targets.
    public var stringValue: String {
        switch self {
        case .lightExploration: return "lightExploration"
        case .mediumStress: return "mediumStress"
        case .heavyReproduction: return "heavyReproduction"
        case .edgeTesting: return "edgeTesting"
        case .performanceBaseline: return "performanceBaseline"
        case .maxStress: return "maxStress"
        }
    }
    
    /// Creates a preset from a string value.
    /// This method avoids RawRepresentable protocol complications across targets.
    public static func from(string: String) -> FocusStressPreset? {
        switch string {
        case "lightExploration": return .lightExploration
        case "mediumStress": return .mediumStress
        case "heavyReproduction": return .heavyReproduction
        case "edgeTesting": return .edgeTesting
        case "performanceBaseline": return .performanceBaseline
        case "maxStress": return .maxStress
        default: return nil
        }
    }
    
    /// The detailed configuration settings for the preset.
    var settings: FocusStressConfiguration {
        switch self {
        case .lightExploration:
            return FocusStressConfiguration(
                layout: .init(numberOfSections: 10, itemsPerSection: 10, nestingLevel: .simple),
                stress: .init(stressors: []),
                navigation: .init(strategy: .snake, pauseBetweenCommands: 0.2),
                performance: .init(prefetchingEnabled: true)
            )
        case .mediumStress:
            return FocusStressConfiguration(
                layout: .init(numberOfSections: 25, itemsPerSection: 35, nestingLevel: .nested),
                stress: .init(stressors: [.jiggleTimer, .hiddenFocusableTraps, .duplicateIdentifiers], jiggleInterval: 0.1, layoutChangeInterval: 0.1),
                navigation: .init(strategy: .spiral, pauseBetweenCommands: 0.1),
                performance: .init(prefetchingEnabled: false)
            )
        case .heavyReproduction:
            return FocusStressConfiguration(
                layout: .init(numberOfSections: 50, itemsPerSection: 50, nestingLevel: .tripleNested),
                stress: .all,
                navigation: .init(strategy: .randomWalk, pauseBetweenCommands: 0.01),
                performance: .init(prefetchingEnabled: false)
            )
        case .edgeTesting:
            return FocusStressConfiguration(
                layout: .init(numberOfSections: 20, itemsPerSection: 20, nestingLevel: .nested),
                stress: .init(stressors: [.circularFocusGuides, .overlappingElements]),
                navigation: .init(strategy: .edgeTest, pauseBetweenCommands: 0.05),
                performance: .init(prefetchingEnabled: false)
            )
        case .performanceBaseline:
            return FocusStressConfiguration(
                layout: .init(numberOfSections: 100, itemsPerSection: 100, nestingLevel: .simple),
                stress: .init(stressors: []),
                navigation: .init(strategy: .snake, pauseBetweenCommands: 0.5),
                performance: .init(prefetchingEnabled: true)
            )
        case .maxStress:
            return FocusStressConfiguration(
                layout: .init(numberOfSections: 150, itemsPerSection: 150, nestingLevel: .tripleNested),
                stress: .init(stressors: [
                    .jiggleTimer,
                    .hiddenFocusableTraps,
                    .circularFocusGuides,
                    .duplicateIdentifiers,
                    .dynamicFocusGuides,
                    .rapidLayoutChanges,
                    .overlappingElements,
                    .voAnnouncements
                ], 
                jiggleInterval: 0.015,
                layoutChangeInterval: 0.008,
                voAnnouncementInterval: 0.12,
                dynamicGuideInterval: 0.03),
                navigation: .init(strategy: .randomWalk, pauseBetweenCommands: 0.025),
                performance: .init(prefetchingEnabled: false)
            )
        }
    }
}

// MARK: - Main Configuration Struct

/// A container for all focus stress test settings.
public struct FocusStressConfiguration {
    public var layout: LayoutConfiguration
    public var stress: StressorConfiguration
    public var navigation: NavigationConfiguration
    public var performance: PerformanceConfiguration

    /// Creates a configuration from a preset.
    public static func from(preset: FocusStressPreset) -> FocusStressConfiguration {
        return preset.settings
    }

    /// Loads configuration from UserDefaults or uses a default preset.
    public static func loadFromDefaults(defaultPreset: FocusStressPreset = .heavyReproduction) -> FocusStressConfiguration {
        // A more robust implementation would parse UserDefaults here.
        return defaultPreset.settings
    }
    
    /// Loads configuration from launch arguments, falling back to a default.
    public static func loadFromLaunchArguments(defaultPreset: FocusStressPreset = .heavyReproduction) -> FocusStressConfiguration {
        let args = ProcessInfo.processInfo.arguments
        if let presetIndex = args.firstIndex(of: "-FocusStressPreset"), args.count > presetIndex + 1 {
            let presetName = args[presetIndex + 1]
            // The preset name might be passed with quote marks from the test runner
            let trimmedName = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
            if let preset = FocusStressPreset.from(string: trimmedName) {
                print("LOADED FocusStressPreset from launch argument: \(presetName)")
                return preset.settings
            } else {
                print("WARNING: Could not find a FocusStressPreset matching '\(presetName)'. Known values are: \(FocusStressPreset.allCases.map { $0.stringValue })")
            }
        }
        
        let defaultPreset = FocusStressPreset.allCases.first!
        print("USING default FocusStressPreset: \(defaultPreset.stringValue)")
        return defaultPreset.settings
    }
}

// MARK: - Sub-Configuration Structs

/// Defines the layout of the collection view.
public struct LayoutConfiguration {
    public var numberOfSections: Int
    public var itemsPerSection: Int
    public var nestingLevel: NestingLevel

    public enum NestingLevel {
        case simple
        case nested
        case tripleNested
    }
}

/// Defines the active stressors.
public struct StressorConfiguration {
    public var stressors: Set<Stressor>
    public var jiggleInterval: TimeInterval = 0.05
    public var layoutChangeInterval: TimeInterval = 0.03
    public var voAnnouncementInterval: TimeInterval = 0.3
    public var dynamicGuideInterval: TimeInterval = 0.1

    public enum Stressor: CaseIterable {
        case nestedLayout // Implicitly handled by LayoutConfiguration
        case hiddenFocusableTraps
        case jiggleTimer
        case circularFocusGuides
        case duplicateIdentifiers
        case dynamicFocusGuides
        case rapidLayoutChanges
        case overlappingElements
        case voAnnouncements
    }

    /// A configuration with all stressors enabled.
    public static let all = StressorConfiguration(stressors: Set(Stressor.allCases))
}

/// Defines navigation behavior for automated tests.
public struct NavigationConfiguration {
    public var strategy: NavigationStrategy
    public var pauseBetweenCommands: TimeInterval

    public enum NavigationStrategy {
        case snake
        case spiral
        case diagonal
        case cross
        case edgeTest
        case randomWalk
    }
}

/// Defines performance-related settings.
public struct PerformanceConfiguration {
    public var prefetchingEnabled: Bool
} 