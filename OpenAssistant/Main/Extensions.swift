import Foundation
import SwiftUI

extension Notification.Name {
    static let settingsUpdated = Notification.Name("settingsUpdated")
    static let assistantCreated = Notification.Name("assistantCreated")
    static let assistantUpdated = Notification.Name("assistantUpdated")
    static let assistantDeleted = Notification.Name("assistantDeleted")
}

// MARK: - View Extension for Keyboard Dismissal

extension View {
    /// Dismisses the keyboard.
    func dismissKeyboard() {
        // Removed the problematic UIApplication.shared.sendAction call.
        // Keyboard dismissal should now be handled via @FocusState.
    }

    /// Applies a transformation to the view only if the specified condition is met,
    /// often used for applying modifiers based on OS version availability.
    @ViewBuilder
    func ifAvailable<Content: View>(@ViewBuilder transform: (Self) -> Content) -> some View {
        transform(self)
    }
}

extension Color {
    static let systemBackground = Color(UIColor.systemBackground)
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
}
