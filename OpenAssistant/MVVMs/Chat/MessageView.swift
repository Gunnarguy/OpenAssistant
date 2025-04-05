import SwiftUI

struct MessageView: View {
    let message: Message
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack {
            MessageBubble(message: message, colorScheme: colorScheme)
                .frame(maxWidth: .infinity, alignment: messageAlignment)
        }
        .padding(.horizontal, 8)
    }
    
    private var messageAlignment: Alignment {
        message.role == .user ? .trailing : .leading
    }
}

struct MessageBubble: View {
    let message: Message
    let colorScheme: ColorScheme

    var body: some View {
        Text(message.content.first?.text?.value ?? "")
            .padding(16)
            .background(messageBackgroundColor)
            .cornerRadius(16)
            .foregroundColor(messageTextColor)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
    }
    
    private var messageBackgroundColor: Color {
        return message.role == .user ? Color.blue.opacity(0.85) : Color(UIColor.systemGray5)
    }
    
    private var messageTextColor: Color {
        return message.role == .user ? Color.white : (colorScheme == .dark ? Color.white : Color.black)
    }
}
