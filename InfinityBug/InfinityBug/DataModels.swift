//
//  DataModels.swift
//  InfinityBug
//
//  Created by Joseph McCraw on 6/1/25.
//

import UIKit

/// Represents a “listing” (e.g. a show/episode) inside a channel’s carousel.
struct Listing: Hashable {
    let id: UUID
    let title: String
    let artworkColor: UIColor
    
    init(title: String) {
        self.id = UUID()
        self.title = title
        // Random pastel‐ish color for the example
        self.artworkColor = UIColor(
            hue: CGFloat(drand48()),
            saturation: 0.3,
            brightness: 0.9,
            alpha: 1.0
        )
    }
}

/// Represents a single “channel” (one row in the EPG).
struct Channel: Hashable {
    let id: UUID
    let name: String
    /// The genre (category) this channel belongs to.
    let genre: Genre
    
    /// Once the async fetch completes, we’ll populate this array.
    /// Initially empty, then updated on a background queue.
    var listings: [Listing] = []
    
    init(name: String, genre: Genre) {
        self.id = UUID()
        self.name = name
        self.genre = genre
    }
}

/// Represents a “category” (genre) on the left side.
struct Genre: Hashable {
    let id: UUID
    let name: String
    
    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}
