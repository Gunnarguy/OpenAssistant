import SwiftUI

struct MessageView: View {
    let message: Message
    let colorScheme: ColorScheme

    private var messageBackgroundColor: Color {
        switch message.role {
        case .user:
            return Color.blue.opacity(0.85)
        default:
            return Color(UIColor.systemGray5)
        }
    }

    private var messageTextColor: Color {
        switch message.role {
        case .user:
            return .white
        default:
            return colorScheme == .dark ? .white : .black
        }
    }

    var body: some View {
        HStack {
            messageContent
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        }
        .padding(.horizontal, 8)
    }

    private var messageContent: some View {
        Text(message.content.first?.text?.value ?? "")
            .padding(16)
            .background(messageBackgroundColor)
            .cornerRadius(16)
            .foregroundColor(messageTextColor)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
    }
}
