import SwiftUI

struct MessageListView: View {
    @ObservedObject var viewModel: ChatViewModel
    var colorScheme: ColorScheme

    var body: some View {
        ScrollViewReader { proxy in
            // Use a standard ScrollView
            ScrollView {
                // Use LazyVStack for performance with many messages
                LazyVStack(spacing: 0) {  // Reduced spacing, handled by MessageView padding
                    ForEach(viewModel.messages) { message in
                        // Use MessageView which contains the styled MessageBubble
                        MessageView(message: message, colorScheme: colorScheme)
                            .id(message.id)  // ID for scrolling
                            // Apply another scaleEffect to flip the content back upright
                            .scaleEffect(x: 1, y: -1, anchor: .center)
                            // Apply transition for new messages
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Add an invisible element at the bottom for scrolling purposes if needed
                    Color.clear
                        .frame(height: 1)
                        .id("bottomSpacer")  // ID for scrolling to bottom if last message isn't enough

                }
                .padding(.top, 10)  // Padding at the top of the list
                .padding(.horizontal, 10)  // Horizontal padding for the entire list content
            }
            // Reverse the scroll view content order and flip it vertically
            // This makes it behave like a typical chat interface (new messages at bottom)
            .scaleEffect(x: 1, y: -1, anchor: .center)
            .onAppear {
                // Set the proxy when the view appears
                viewModel.setScrollViewProxy(proxy)
                // Initial scroll to bottom (or most recent message)
                viewModel.scrollToLastMessage(animated: false)  // No animation on initial appear
            }
            .onChange(of: viewModel.messages.count) { _ in
                // Scroll when new messages are added
                viewModel.scrollToLastMessage(animated: true)  // Animate scroll for new messages
            }
            .onDisappear {
                // Clear the proxy when the view disappears
                viewModel.setScrollViewProxy(nil)
            }
            // Apply default scroll anchor to the bottom conditionally for iOS 17+
            .ifAvailable { view in
                if #available(iOS 17.0, *) {
                    view.defaultScrollAnchor(.bottom)
                } else {
                    view  // Return unchanged view for older versions
                }
            }
        }
        // Add animation for message changes
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.messages)
    }
}
