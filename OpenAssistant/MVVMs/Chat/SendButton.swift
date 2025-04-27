import SwiftUI

struct SendButton: View {
    // Action to perform when tapped
    var action: () -> Void
    // State properties passed from the parent view
    var isDisabled: Bool
    var isLoading: Bool

    var body: some View {
        Button(action: action) {
            // Use a capsule shape for the background
            Image(systemName: "arrow.up")  // Changed icon to arrow.up for a cleaner look
                .font(.system(size: 16, weight: .medium))  // Reduced size/weight
                .foregroundColor(isDisabled ? .gray : .white)
                .padding(10)  // Reduced padding
                .background(isDisabled ? Color.gray.opacity(0.4) : Color.accentColor)  // Adjusted disabled background
                .clipShape(Circle())  // Use Circle shape for a compact button
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)  // Reduced shadow
                .accessibilityLabel("Send Message")
                // Overlay ProgressView when loading
                .overlay {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(10)  // Match reduced padding
                            .background(Color.accentColor)  // Ensure background matches
                            .clipShape(Circle())  // Match button shape
                    }
                }
        }
        .disabled(isDisabled || isLoading)  // Disable based on props
        .animation(.easeInOut(duration: 0.15), value: isLoading)  // Faster animation
        .animation(.easeInOut(duration: 0.15), value: isDisabled)  // Faster animation
    }
}
