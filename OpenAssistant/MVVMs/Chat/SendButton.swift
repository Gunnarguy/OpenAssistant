import SwiftUI

struct SendButton: View {
    // Action to perform when tapped
    var action: () -> Void
    // State properties passed from the parent view
    var isDisabled: Bool
    var isLoading: Bool

    var body: some View {
        Button(action: action) {  // Use the provided action
            Image(systemName: "paperplane.fill")
                .foregroundColor(isDisabled ? .gray : .white)  // Use isDisabled
                .padding(16)
                .background(isDisabled ? Color.gray.opacity(0.6) : Color.blue)  // Use isDisabled
                .cornerRadius(25)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                .accessibilityLabel("Send Message")
        }
        .disabled(isDisabled || isLoading)  // Disable based on props
        // Add optional progress view for loading state if desired
        // .overlay {
        //     if isLoading {
        //         ProgressView()
        //             .tint(.white)
        //     }
        // }
    }

    // Removed sendMessageAction and canSendMessage
}
