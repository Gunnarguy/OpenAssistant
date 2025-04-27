import SwiftUI

struct MessageView: View {
    let message: Message
    let colorScheme: ColorScheme

    var body: some View {
        MessageBubble(message: message, colorScheme: colorScheme)
            .frame(maxWidth: .infinity, alignment: messageAlignment)
            .padding(messageAlignment == .leading ? .trailing : .leading, 35)  // Reduced side padding
            .padding(.vertical, 3)  // Reduced vertical padding between messages
    }

    // Determine alignment based on message role
    private var messageAlignment: Alignment {
        message.role == .user ? .trailing : .leading
    }
}

struct MessageBubble: View {
    let message: Message
    let colorScheme: ColorScheme

    var body: some View {
        // Use Markdown for assistant messages (iOS 15+), plain text otherwise
        Group {
            // Extract the text content safely
            let messageText = message.content.first?.text?.value ?? "..."

            if message.role == .assistant {
                if #available(iOS 15.0, *) {
                    // Render assistant message content as Markdown using the extracted string
                    // Note: The initializer is just Text(_:) which accepts a String directly
                    // when it contains markdown formatting on iOS 15+.
                    // The explicit 'markdown:' label is not used.
                    Text(messageText)
                } else {
                    // Fallback to plain text for older iOS versions
                    Text(messageText)
                }
            } else {
                // User messages remain plain text
                Text(messageText)
            }
        }
        .padding(.horizontal, 12)  // Reduced padding
        .padding(.vertical, 8)  // Reduced padding
        .background(messageBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))  // Adjusted radius
        .foregroundColor(messageTextColor)
        // Apply base font styling here, Markdown will override specific elements
        .font(.system(size: 15, weight: .regular, design: .default))  // Base font size
        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)  // Reduced shadow
        .lineLimit(nil)  // Ensure text can wrap
        .fixedSize(horizontal: false, vertical: true)  // Allow vertical expansion
        // Apply text selection for easier copying (iOS 15+)
        .ifAvailable { view in
            if #available(iOS 15.0, *) {
                view.textSelection(.enabled)
            } else {
                view
            }
        }
    }

    // Determine background color based on role and color scheme
    private var messageBackgroundColor: Color {
        if message.role == .user {
            return Color.accentColor  // Use accent color for user
        } else {
            // Use system gray shades that adapt to light/dark mode
            return Color(UIColor.systemGray5)
        }
    }

    // Determine text color based on role and color scheme
    private var messageTextColor: Color {
        if message.role == .user {
            return Color.white  // White text on accent color
        } else {
            // Use primary label color which adapts to light/dark mode
            return Color(UIColor.label)
        }
    }
}
