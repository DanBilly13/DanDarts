//
//  NavigationManager.swift
//  Dart Freak
//
//  Simple navigation manager to handle dismiss to root functionality
//

import Foundation
import SwiftUI

class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var shouldDismissToGamesList: Bool = false
    
    private init() {}
    
    func dismissToGamesList() {
        shouldDismissToGamesList = true
    }
    
    func resetDismissFlag() {
        shouldDismissToGamesList = false
    }
}
