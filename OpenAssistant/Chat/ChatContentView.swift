import SwiftUI

struct ChatContentView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    var colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(viewModel: viewModel, colorScheme: colorScheme)
            Spacer()
            InputView(viewModel: viewModel, messageStore: messageStore, colorScheme: colorScheme)
                .padding(.horizontal)
            StepCounterView(stepCounter: viewModel.stepCounter)
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
        .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all))
    }
}
