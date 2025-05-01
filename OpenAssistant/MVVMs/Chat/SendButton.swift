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

// MARK: - Previews
#if DEBUG
    struct SendButton_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                // Enabled state
                SendButton(action: {}, isDisabled: false, isLoading: false)
                    .padding()
                    .previewLayout(.sizeThatFits)
                    .previewDisplayName("Enabled")

                // Disabled state (e.g., empty input)
                SendButton(action: {}, isDisabled: true, isLoading: false)
                    .padding()
                    .previewLayout(.sizeThatFits)
                    .previewDisplayName("Disabled")

                // Loading state
                SendButton(action: {}, isDisabled: false, isLoading: true)
                    .padding()
                    .previewLayout(.sizeThatFits)
                    .previewDisplayName("Loading")

                // Disabled while Loading state (should look same as Loading)
                SendButton(action: {}, isDisabled: true, isLoading: true)
                    .padding()
                    .previewLayout(.sizeThatFits)
                    .previewDisplayName("Disabled & Loading")

                // Enabled state (Dark Mode)
                SendButton(action: {}, isDisabled: false, isLoading: false)
                    .padding()
                    .background(Color.black)
                    .previewLayout(.sizeThatFits)
                    .previewDisplayName("Enabled (Dark)")

                // Disabled state (Dark Mode)
                SendButton(action: {}, isDisabled: true, isLoading: false)
                    .padding()
                    .background(Color.black)
                    .previewLayout(.sizeThatFits)
                    .previewDisplayName("Disabled (Dark)")
            }
        }
    }
#endif
