import SwiftUI

struct ChatHistoryView: View {
    @EnvironmentObject var messageStore: MessageStore
    let assistantId: String  // Changed from threadId
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if filteredMessages.isEmpty {
                    Text("No history found for this assistant")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 50)
                } else {
                    ForEach(filteredMessages) { message in
                        MessageRow(message: message, colorScheme: colorScheme)
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        Divider().padding(.leading)
                    }
                }
            }
        }
        .navigationTitle("Assistant History")
        .background(Color(UIColor.systemGroupedBackground))
    }

    private var filteredMessages: [Message] {
        print("ChatHistoryView: Filtering messages.")
        print("  - Received assistantId: \(assistantId)")
        let totalMessagesInStore = messageStore.messages.count
        print("  - Total messages in MessageStore: \(totalMessagesInStore)")

        let filtered = messageStore.messages
            .filter { $0.assistant_id == assistantId }
            .sorted { $0.created_at < $1.created_at }

        print("  - Found \(filtered.count) messages matching assistantId \(assistantId).")

        return filtered
    }
}

struct MessageRow: View {
    let message: Message
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: message.role == .user ? "person.fill" : "brain.head.profile")
                    .font(.caption2)
                    .foregroundColor(roleColor)
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.caption)
                    .foregroundColor(roleColor)

                Spacer()

                Text(formatDate(message.created_at))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let text = message.content.first?.text?.value, !text.isEmpty {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(Color(UIColor.label))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("...")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var roleColor: Color {
        message.role == .user ? .accentColor : .green
    }

    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
