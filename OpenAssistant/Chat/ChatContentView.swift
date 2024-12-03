import SwiftUI

struct ChatContentView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    var colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(viewModel: viewModel, colorScheme: colorScheme)
            if viewModel.isLoading {
                LoadingProgressView(viewModel: viewModel)
                    .padding(.vertical, 10)
            }
            InputView(viewModel: viewModel, messageStore: messageStore, colorScheme: colorScheme)
        }
        .padding(.horizontal)
        .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all))
    }
}
