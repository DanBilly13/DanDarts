//
//  MenuCoordinator.swift
//  Dart Freak
//
//  Singleton coordinator for managing popup menus across the app
//  Ensures only one menu is active at a time
//

import SwiftUI

class MenuCoordinator: ObservableObject {
    static let shared = MenuCoordinator()
    @Published var activeMenuId: String? = nil
    
    private init() {}
    
    func showMenu(for buttonId: String) {
        activeMenuId = buttonId
    }
    
    func hideMenu() {
        activeMenuId = nil
    }
}
