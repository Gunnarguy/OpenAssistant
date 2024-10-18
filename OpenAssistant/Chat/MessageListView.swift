import SwiftUI

struct MessageListView: View {
    @ObservedObject var viewModel: ChatViewModel
    var colorScheme: ColorScheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    messageList
                    loadingIndicator
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: viewModel.messages) { _ in
                    scrollToLastMessage(proxy: proxy)
                }
                .onChange(of: viewModel.isLoading) { _ in
                    scrollToLoadingIndicator(proxy: proxy)
                }
            }
            .onAppear {
                viewModel.scrollViewProxy = proxy
                viewModel.createThread()
                scrollToLastMessage(proxy: proxy)
            }
            .background(Color.clear)
        }
    }

    private var messageList: some View {
        ForEach(viewModel.messages) { message in
            MessageView(message: message, colorScheme: colorScheme)
        }
    }

    private var loadingIndicator: some View {
        Group {
            if viewModel.isLoading {
                NewCustomLoadingIndicator()
                    .padding(.vertical, 10)
                    .id("loadingIndicator")
            }
        }
    }

    private func scrollToLastMessage(proxy: ScrollViewProxy) {
        if let lastMessageId = viewModel.messages.last?.id {
            proxy.scrollTo(lastMessageId, anchor: .bottom)
        }
    }

    private func scrollToLoadingIndicator(proxy: ScrollViewProxy) {
        if viewModel.isLoading {
            proxy.scrollTo("loadingIndicator", anchor: .bottom)
        }
    }
}
