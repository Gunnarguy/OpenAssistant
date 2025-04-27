import SwiftUI

struct ChatContentView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    var colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {  // Keep spacing 0
            // Message list takes available space
            MessageListView(viewModel: viewModel, colorScheme: colorScheme)

            // Loading indicator shown conditionally below messages
            if viewModel.isLoading {
                LoadingProgressView(viewModel: viewModel)
                    .padding(.vertical, 5)  // Further reduced padding
            }

            // Input view sticks to the bottom
            InputView(viewModel: viewModel, messageStore: messageStore, colorScheme: colorScheme)
                .padding(.horizontal, 10)  // Reduced horizontal padding
                .padding(.bottom, 5)  // Reduced bottom padding
        }
        // Apply background to the entire content view
        .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.bottom))  // Ignore only bottom safe area for background
    }
}

// Enhanced LoadingProgressView to show state description
private struct LoadingProgressView: View {
    @ObservedObject var viewModel: ChatViewModel  // Use ObservedObject if it needs to react to changes

    var body: some View {
        HStack(spacing: 6) {  // Reduced spacing
            ProgressView()
                .scaleEffect(0.8)  // Make progress view smaller
                .progressViewStyle(CircularProgressViewStyle(tint: .secondary))  // Style the progress view
            // Display the description from the loading state enum
            Text(viewModel.loadingState.description)
                .font(.caption2)  // Smaller caption
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)  // Center the indicator
    }
}
