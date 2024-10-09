import SwiftUI

struct MessageListView: View {
    @ObservedObject var viewModel: ChatViewModel
    var colorScheme: ColorScheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageView(message: message, colorScheme: colorScheme)
                    }
                    if viewModel.isLoading {
                        NewCustomLoadingIndicator()
                            .padding(.vertical, 10)
                            .id("loadingIndicator")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: viewModel.messages) { _ in
                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
                .onChange(of: viewModel.isLoading) { _ in
                    if viewModel.isLoading {
                        proxy.scrollTo("loadingIndicator", anchor: .bottom)
                    }
                }
            }
            .onAppear {
                viewModel.scrollViewProxy = proxy
                viewModel.createThread()
                viewModel.scrollToLastMessage()
            }
            .background(Color.clear)
        }
    }
}
