import SwiftUI

struct InputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    var colorScheme: ColorScheme

    var body: some View {
        HStack {
            NavigationLink(destination: ChatHistoryView(messages: messageStore.messages, assistantId: viewModel.assistant.id)) {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                    .padding(14)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(25)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
            }
            TextField("Type a message", text: $viewModel.inputText, onCommit: viewModel.sendMessage)
                .padding(16)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(25)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.blue, lineWidth: 1)
                )
            SendButton(viewModel: viewModel, messageStore: messageStore)
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
}
