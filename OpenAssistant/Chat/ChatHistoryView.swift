import SwiftUI

struct ChatHistoryView: View {
    let messages: [Message]
    let assistantId: String

    var body: some View {
        List(filteredMessages) { message in
            VStack(alignment: .leading) {
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.headline)
                Text(message.content.first?.text?.value ?? "")
                    .font(.body)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Chat History")
    }

    private var filteredMessages: [Message] {
        messages.filter { $0.assistant_id == assistantId }
    }
}
