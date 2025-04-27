import SwiftUI

struct ChatHistoryView: View {
    @ObservedObject var messageStore: MessageStore
    let threadId: String
    @Environment(\.colorScheme) var colorScheme  // Access color scheme

    var body: some View {
        // Use a ScrollView for custom row backgrounds/padding if needed, or List for standard behavior
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {  // Align content leading, no extra spacing
                if filteredMessages.isEmpty {
                    Text("No messages in this conversation")
                        .foregroundColor(.secondary)  // Use secondary color
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 50)  // Add more padding for empty state
                } else {
                    // Iterate through messages, sorted chronologically (oldest first)
                    ForEach(filteredMessages.reversed()) { message in
                        MessageRow(message: message, colorScheme: colorScheme)
                            .padding(.horizontal)  // Add horizontal padding to the row content
                            .padding(.vertical, 6)  // Reduced vertical padding
                        Divider().padding(.leading)  // Add divider, indented
                    }
                }
            }
        }
        .navigationTitle("Chat History")
        // .listStyle(.plain) // Use plain list style for edge-to-edge rows if using List
        .background(Color(UIColor.systemGroupedBackground))  // Use grouped background for contrast
    }

    // Filter and sort messages (most recent first for internal logic)
    private var filteredMessages: [Message] {
        // Log the filtering process
        // print("ChatHistoryView: Filtering messages for threadId: \(threadId)")
        // let allMessagesCount = messageStore.messages.count
        // print("ChatHistoryView: Total messages in store: \(allMessagesCount)")

        let filtered = messageStore.messages
            .filter { $0.thread_id == threadId }
            .sorted { $0.created_at < $1.created_at }  // Sort oldest first

        // Log the result of the filtering
        // print("ChatHistoryView: Found \(filtered.count) messages for this thread.")
        return filtered
    }
}

struct MessageRow: View {
    let message: Message
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {  // Reduced spacing
            HStack {
                // Role indicator with icon
                Image(systemName: message.role == .user ? "person.fill" : "brain.head.profile")
                    .font(.caption2)  // Smaller icon font
                    .foregroundColor(roleColor)
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.caption)  // Use regular caption
                    .foregroundColor(roleColor)

                Spacer()

                // Timestamp
                Text(formatDate(message.created_at))
                    .font(.caption2)  // Keep small
                    .foregroundColor(.secondary)  // Use secondary color
            }

            // Message content
            if let text = message.content.first?.text?.value, !text.isEmpty {
                Text(text)
                    .font(.system(size: 15))  // Slightly smaller body font
                    .foregroundColor(Color(UIColor.label))  // Adapts to light/dark
                    .lineLimit(nil)  // Allow multiple lines
                    .fixedSize(horizontal: false, vertical: true)  // Allow vertical expansion
            } else {
                Text("...")  // Placeholder for empty messages
                    .font(.system(size: 15))  // Match body font
                    .foregroundColor(.secondary)
            }
        }
        // Removed explicit background color from the row itself
        // .padding(10)
        // .background(...)
    }

    // Determine color based on role
    private var roleColor: Color {
        message.role == .user ? .accentColor : .green  // Use accent for user, green for assistant
    }

    // Format timestamp to a readable date/time string
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
