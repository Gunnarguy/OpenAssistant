import SwiftUI

struct SendButton: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore

    var body: some View {
        Button(action: sendMessageAction) {
            Image(systemName: "paperplane.fill")
                .foregroundColor(viewModel.inputText.isEmpty || viewModel.isLoading ? .gray : .white)
                .padding(16)
                .background(viewModel.inputText.isEmpty || viewModel.isLoading ? Color.gray.opacity(0.6) : Color.blue)
                .cornerRadius(25)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
        }
        .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
    }

    private func sendMessageAction() {
        viewModel.sendMessage()
        if let lastMessage = viewModel.messages.last {
            messageStore.addMessage(lastMessage)
        }
    }
}
