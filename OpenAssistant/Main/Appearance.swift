import Foundation
import SwiftUI  // Import SwiftUI for ColorScheme

// Define the appearance modes accessible within the module
// Removed public modifier as internal (default) is usually sufficient within a single target.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    var id: String { self.rawValue }  // Default internal access

    // Helper function to map AppearanceMode to ColorScheme
    // Removed public modifier.
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil  // nil uses the system setting
        }
    }
}
