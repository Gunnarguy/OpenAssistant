import SwiftUI

struct MessageView: View {
    let message: Message
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            Text(message.content.first?.text?.value ?? "")
                .padding(16)
                .background(message.role == .user ? Color.blue.opacity(0.85) : Color(UIColor.systemGray5))
                .cornerRadius(16)
                .foregroundColor(message.role == .user ? .white : (colorScheme == .dark ? .white : .black))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
            if message.role != .user {
                Spacer()
            }
        }
        .padding(.horizontal, 8)
    }
}
