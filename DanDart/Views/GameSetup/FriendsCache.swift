//
//  FriendsCache.swift
//  Dart Freak
//
//  Persistent cache for friends data to avoid reloading on sheet presentations
//

import SwiftUI

/// Observable cache that persists friends data across sheet presentations
/// This prevents the "wonky" reload behavior when opening the Add Player sheet multiple times
class FriendsCache: ObservableObject {
    @Published var friends: [Player] = []
    @Published var hasFriendsLoaded = false
}
