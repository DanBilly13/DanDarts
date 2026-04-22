//
//  String+AbbreviatedName.swift
//  Dart Freak
//
//  Extension to abbreviate full names (e.g., "Daniel Billingham" -> "Daniel B")
//

import Foundation

extension String {
    /// Abbreviates a full name by showing only the first letter of the last name
    /// - Returns: Abbreviated name (e.g., "Daniel Billingham" -> "Daniel B")
    func abbreviatedName() -> String {
        let components = self.split(separator: " ")
        guard components.count > 1 else {
            return self
        }
        
        let firstName = components[0]
        let lastNameInitial = components.last?.prefix(1) ?? ""
        
        return "\(firstName) \(lastNameInitial)"
    }
}
