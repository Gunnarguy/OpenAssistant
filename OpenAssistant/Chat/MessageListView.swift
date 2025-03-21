// MARK: - CodeAI Output
import SwiftUI

protocol MessageListViewProtocol {
    var viewModel: ChatViewModel { get }
    var colorScheme: ColorScheme { get }
    
    func scrollToLastMessage(proxy: ScrollViewProxy)
    func scrollToLoadingIndicator(proxy: ScrollViewProxy)
}

struct MessageListView: View {
    @ObservedObject var viewModel: ChatViewModel
    var colorScheme: ColorScheme
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message, colorScheme: colorScheme)
                            .id(message.id)
                    }
                    
                    // Add spacer at the bottom to allow scrolling past the last message
                    Spacer(minLength: 60)
                }
                .padding(.top, 10)
            }
            .onAppear {
                // Safely set the proxy when the view appears
                viewModel.setScrollViewProxy(proxy)
                
                // Scroll to last message with a delay to ensure layout is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.scrollToLastMessage()
                }
            }
            .onChange(of: viewModel.messages.count) { _ in
                // Scroll when messages change
                viewModel.scrollToLastMessage()
            }
            // Important: Clear the proxy reference when the view disappears
            .onDisappear {
                viewModel.setScrollViewProxy(nil)
            }
        }
    }
}
