import SwiftUI

struct ChatHistoryView: View {
    let messages: [Message]
    let assistantId: String

    var body: some View {
        List {
            ForEach(filteredMessages) { message in
                MessageRow(message: message)
            }
        }
        .navigationTitle("Chat History")
    }

    private var filteredMessages: [Message] {
        messages.filter { $0.assistant_id == assistantId }
    }
}

struct MessageRow: View {
    let message: Message

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role == .user ? "You" : "Assistant")
                .font(.headline)
            if let text = message.content.first?.text?.value {
                Text(text)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
    }
}
