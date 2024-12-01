import SwiftUI

struct ChatContentView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    var colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(viewModel: viewModel, colorScheme: colorScheme)
            InputView(viewModel: viewModel, messageStore: messageStore, colorScheme: colorScheme)
            if viewModel.isLoading {
                CustomProgressView(stepCounter: viewModel.stepCounter)
                    .padding(.bottom, 10)
            }
            StepCounterView(stepCounter: viewModel.stepCounter)
                .padding(.bottom, 10)
        }
        .padding(.horizontal)
        .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all))
    }
}
