import Combine
import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject var messageStore: MessageStore  // Use EnvironmentObject for body/subviews
    @Environment(\.colorScheme) var colorScheme

    // Revert initializer to accept messageStore
    init(assistant: Assistant, messageStore: MessageStore) {
        // Initialize viewModel, passing the received messageStore
        _viewModel = StateObject(
            wrappedValue: ChatViewModel(assistant: assistant, messageStore: messageStore))
    }

    var body: some View {
        // Pass viewModel AND messageStore explicitly to ChatContentView initializer
        ChatContentView(viewModel: viewModel, messageStore: messageStore, colorScheme: colorScheme)
            .navigationTitle(viewModel.assistant.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Use assistant ID for the history link
                    let assistantId = viewModel.assistant.id
                    let _ = print(
                        "ChatView Toolbar: Using assistantId \(assistantId) for NavigationLink")

                    // Enable link if assistantId is valid
                    if !assistantId.isEmpty {
                        NavigationLink(
                            // Pass assistantId to ChatHistoryView
                            destination: ChatHistoryView(
                                assistantId: assistantId  // Pass assistantId
                            )
                        ) {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                        }
                    } else {
                        // Disable if assistantId is somehow empty
                        let _ = print(
                            "ChatView Toolbar: Disabling NavigationLink (assistantId is empty)")
                        Image(systemName: "clock")
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
            .alert(item: $viewModel.errorMessage) { errorMessage in
                Alert(
                    title: Text("Error"), message: Text(errorMessage.message),
                    dismissButton: .default(Text("OK")))
            }
        // Ensure ChatContentView and ChatHistoryView also use @EnvironmentObject
    }
}

// Update Preview Provider to pass a dummy MessageStore to the initializer
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy assistant for the preview
        let assistant = Assistant(
            id: "preview_assist_1", object: "assistant", created_at: 1_678_886_400,
            name: "Preview Assistant", description: "Assistant for SwiftUI Preview",
            model: "gpt-preview", vectorStoreId: nil, instructions: nil, threads: nil, tools: [],
            top_p: 1.0, temperature: 0.7, reasoning_effort: nil, tool_resources: nil,
            metadata: nil, response_format: nil, file_ids: []
        )
        let dummyStore = MessageStore()  // Create dummy store for preview
        // Provide the store to the initializer AND the environment
        ChatView(assistant: assistant, messageStore: dummyStore)
            .environmentObject(dummyStore)
    }
}
