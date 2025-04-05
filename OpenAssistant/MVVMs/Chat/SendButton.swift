import SwiftUI

struct SendButton: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore

    var body: some View {
        Button(action: sendMessageAction) {
            Image(systemName: "paperplane.fill")
                .foregroundColor(canSendMessage ? .white : .gray)
                .padding(16)
                .background(canSendMessage ? Color.blue : Color.gray.opacity(0.6))
                .cornerRadius(25)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                .accessibilityLabel("Send Message")
        }
        .disabled(!canSendMessage)
    }

    private func sendMessageAction() {
        viewModel.sendMessage()
        if let lastMessage = viewModel.messages.last {
            messageStore.addMessage(lastMessage)
        }
    }

    private var canSendMessage: Bool {
        !viewModel.inputText.isEmpty && !viewModel.isLoading
    }
}
