//
//  ContainerFactory.swift
//  InfinityBugDiagnostics
//
//  Created by You on 2025-06-13.
//

import UIKit
import SwiftUI

// MARK: – Random Helpers ----------------------------------------------------

private enum Animal: CaseIterable {
    case cat, dog, panda, koala, owl, otter, sloth
    var traits: (name: String, sound: String, habitat: String) {
        switch self {
        case .cat:   return ("Cat",   "Meow",    "House")
        case .dog:   return ("Dog",   "Woof",    "Yard")
        case .panda: return ("Panda", "Bleat",   "Bamboo Forest")
        case .koala: return ("Koala", "Grunt",   "Eucalyptus Tree")
        case .owl:   return ("Owl",   "Hoot",    "Forest")
        case .otter: return ("Otter", "Chirp",   "Riverbank")
        case .sloth: return ("Sloth", "Hum",     "Rainforest")
        }
    }
    static func random() -> Animal { Animal.allCases.randomElement()! }
}

private enum Plant: CaseIterable {
    case oak, rose, cactus, bamboo, fern, orchid, tulip
    var traits: (name: String, scientific: String, climate: String) {
        switch self {
        case .oak:     return ("Oak",     "Quercus",   "Temperate")
        case .rose:    return ("Rose",    "Rosa",      "Temperate")
        case .cactus:  return ("Cactus",  "Cactaceae", "Arid")
        case .bamboo:  return ("Bamboo",  "Bambusoideae", "Sub-tropical")
        case .fern:    return ("Fern",    "Polypodiopsida", "Humid")
        case .orchid:  return ("Orchid",  "Orchidaceae", "Tropical")
        case .tulip:   return ("Tulip",   "Tulipa",    "Temperate")
        }
    }
    static func random() -> Plant { Plant.allCases.randomElement()! }
}

/// Random opaque colour with 90 % brightness (keeps text readable)
private func randomUIColor() -> UIColor {
    UIColor(
        hue:   .random(in: 0...1),
        saturation: 0.4 + .random(in: 0...0.6),
        brightness: 0.9,
        alpha: 1
    )
}

// MARK: – SwiftUI wrapper for arbitrary UIViewController --------------------

private struct PaddedControllerView: UIViewControllerRepresentable {
    let embedded: UIViewController
    let padding: CGFloat
    let background: Color
    let animal: Animal
    var toggleAccessibilityElementTransparencySetting: Bool = false
    
    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        container.view.backgroundColor = UIColor(background)
        
        // Accessibility (Animal)
        let traits = animal.traits
        
        if toggleAccessibilityElementTransparencySetting {
            // Make container transparent to accessibility
            container.view.isAccessibilityElement = false
            container.view.accessibilityElementsHidden = false
        } else {
            // Original behavior with accessibility properties
            container.view.isAccessibilityElement = true
            container.view.accessibilityElementsHidden = true
            
            container.view.accessibilityLabel  = traits.name
            container.view.accessibilityValue  = traits.sound
            container.view.accessibilityHint   = "Habitat: \(traits.habitat)"
            container.view.accessibilityIdentifier = "Animal-\(traits.name)"
        }
        
        // Child VC embedding
        container.addChild(embedded)
        embedded.view.translatesAutoresizingMaskIntoConstraints = false
        container.view.addSubview(embedded.view)
        NSLayoutConstraint.activate([
            embedded.view.leadingAnchor.constraint(equalTo: container.view.leadingAnchor, constant: padding),
            embedded.view.trailingAnchor.constraint(equalTo: container.view.trailingAnchor, constant: -padding),
            embedded.view.topAnchor.constraint(equalTo: container.view.topAnchor, constant: padding),
            embedded.view.bottomAnchor.constraint(equalTo: container.view.bottomAnchor, constant: -padding)
        ])
        embedded.didMove(toParent: container)
        
        NSLog("[Factory] Embedded VC \(type(of: embedded)) inside SwiftUI container \(traits.name).")
        return container
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // no dynamic updates
    }
}

// MARK: – Factory -----------------------------------------------------------

public enum ContainerFactory {
    
    /// Wraps `childVC` in the required two-layer structure and returns the outermost UIViewController.
    ///
    /// - Parameter childVC: The view controller to embed.
    /// - Returns: A fully-configured parent UIViewController.
    public static func wrap(_ childVC: UIViewController) -> UIViewController {
        let isTestMode = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                        ProcessInfo.processInfo.arguments.contains("-FocusTestMode")
        
        if isTestMode {
            return wrapForTesting(childVC)
        } else {
            return wrapWithConflicts(childVC)
        }
    }
    
    /// Testing-friendly wrapper that maintains some complexity without breaking accessibility
    private static func wrapForTesting(_ childVC: UIViewController) -> UIViewController {
        let innerAnimal: Animal = .random()
        let outerPlant: Plant = .random()
        
        // 1️⃣ SwiftUI hosting controller around the childVC
        let hosting = UIHostingController(
            rootView: PaddedControllerView(
                embedded: childVC,
                padding: 10,
                background: Color(randomUIColor()),
                animal: innerAnimal,
                toggleAccessibilityElementTransparencySetting: true  // Make transparent for testing
            )
        )
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        // 2️⃣ Outer UIKit parent - REDUCED conflicts for testing
        let parentVC = UIViewController()
        parentVC.view.backgroundColor = randomUIColor()
        // Don't make parent accessible in test mode - let child elements be accessible
        parentVC.view.isAccessibilityElement = false
        
        let plantTraits = outerPlant.traits
        parentVC.view.accessibilityIdentifier = "Plant-\(plantTraits.name)"
        
        // 3️⃣ Embed hosting controller with 10 pt padding
        parentVC.addChild(hosting)
        parentVC.view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: parentVC.view.leadingAnchor, constant: 10),
            hosting.view.trailingAnchor.constraint(equalTo: parentVC.view.trailingAnchor, constant: -10),
            hosting.view.topAnchor.constraint(equalTo: parentVC.view.topAnchor, constant: 10),
            hosting.view.bottomAnchor.constraint(equalTo: parentVC.view.bottomAnchor, constant: -10)
        ])
        hosting.didMove(toParent: parentVC)
        
        NSLog("[Factory] Created TESTING-FRIENDLY wrapper with plant \"\(plantTraits.name)\" containing animal \"\(innerAnimal.traits.name)\"")
        
        // NO accessibility override in test mode - let normal hierarchy work
        return parentVC
    }
    
    /// Original conflict-heavy wrapper for InfinityBug reproduction
    private static func wrapWithConflicts(_ childVC: UIViewController) -> UIViewController {
        let innerAnimal: Animal = .random()
        let outerPlant: Plant = .random()
        
        // 1️⃣ SwiftUI hosting controller around the childVC
        let hosting = UIHostingController(
            rootView: PaddedControllerView(
                embedded: childVC,
                padding: 10,
                background: Color(randomUIColor()),
                animal: innerAnimal,
                toggleAccessibilityElementTransparencySetting: false
            )
        )
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        // 2️⃣ Outer UIKit parent - KEEP accessibility conflicts
        let parentVC = UIViewController()
        parentVC.view.backgroundColor = randomUIColor()
        parentVC.view.isAccessibilityElement = true
        
        let plantTraits = outerPlant.traits
        parentVC.view.accessibilityLabel = plantTraits.name
        parentVC.view.accessibilityValue = plantTraits.scientific
        parentVC.view.accessibilityHint = "Climate: \(plantTraits.climate)"
        parentVC.view.accessibilityIdentifier = "Plant-\(plantTraits.name)"
        
        // 3️⃣ Embed hosting controller with 10 pt padding
        parentVC.addChild(hosting)
        parentVC.view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: parentVC.view.leadingAnchor, constant: 10),
            hosting.view.trailingAnchor.constraint(equalTo: parentVC.view.trailingAnchor, constant: -10),
            hosting.view.topAnchor.constraint(equalTo: parentVC.view.topAnchor, constant: 10),
            hosting.view.bottomAnchor.constraint(equalTo: parentVC.view.bottomAnchor, constant: -10)
        ])
        hosting.didMove(toParent: parentVC)
        
        NSLog("""
        [Factory] Created CONFLICTED parent VC with plant \"\(plantTraits.name)\" \
        containing animal \"\(innerAnimal.traits.name)\" - INTENTIONAL ACCESSIBILITY CONFLICTS
        """)
        
        // KEEP the accessibility override that creates conflicts - but only in non-test mode
        DispatchQueue.main.async {
            if let sampleVC = childVC as? SampleViewController {
                let collectionView = sampleVC.debugCollectionView
                
                // This creates accessibility conflicts by overriding the collection view's properties
                parentVC.view.accessibilityElements = [collectionView]
                hosting.view.accessibilityElements = [collectionView]
            }
        }
        
        return parentVC
    }
} 
