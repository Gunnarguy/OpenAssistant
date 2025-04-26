import SwiftUI

struct ChatHistoryView: View {
    // Accept the MessageStore as an ObservedObject instead of just the messages array
    @ObservedObject var messageStore: MessageStore
    let threadId: String

    var body: some View {
        List {
            if filteredMessages.isEmpty {
                Text("No messages in this conversation")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(filteredMessages) { message in
                    MessageRow(message: message)
                        .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Chat History")
        .listStyle(PlainListStyle())
    }

    private var filteredMessages: [Message] {
        // Access messages from the messageStore
        messageStore.messages.filter { $0.thread_id == threadId }
            .sorted {
                // Remove the nil coalescing since created_at is not optional
                $0.created_at > $1.created_at
            }
    }
}

struct MessageRow: View {
    let message: Message

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.headline)
                    .foregroundColor(message.role == .user ? .blue : .green)

                Spacer()

                // Remove nil coalescing since created_at is not optional
                Text(formatDate(message.created_at))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            if let text = message.content.first?.text?.value {
                Text(text)
                    .font(.body)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(message.role == .user ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
        )
    }

    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
