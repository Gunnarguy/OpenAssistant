import SwiftUI
import Combine

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @ObservedObject var messageStore: MessageStore
    @Environment(\.colorScheme) var colorScheme

    init(assistant: Assistant, messageStore: MessageStore) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(assistant: assistant, messageStore: messageStore))
        self.messageStore = messageStore
    }

    var body: some View {
        ChatContentView(viewModel: viewModel, messageStore: messageStore, colorScheme: colorScheme)
            .navigationTitle(viewModel.assistant.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let threadId = viewModel.threadId, !threadId.isEmpty {
                        NavigationLink(destination: ChatHistoryView(messages: messageStore.messages, threadId: threadId)) {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                        }
                    } else {
                        Image(systemName: "clock")
                            .foregroundColor(.gray.opacity(0.5)) // Clearly disabled
                    }
                }
            }
            .alert(item: $viewModel.errorMessage) { errorMessage in
                Alert(title: Text("Error"), message: Text(errorMessage.message), dismissButton: .default(Text("OK")))
            }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        let assistant = Assistant(
            id: "1",
            object: "assistant",
            created_at: Int(Date().timeIntervalSince1970),
            name: "Test Assistant",
            description: "This is a test assistant.",
            model: "test-model",
            instructions: nil,
            threads: nil,
            tools: [],
            top_p: 1.0,
            temperature: 0.7,
            tool_resources: nil,
            metadata: nil,
            response_format: nil,
            file_ids: []
        )
        let messageStore = MessageStore()
        ChatView(assistant: assistant, messageStore: messageStore)
    }
}
