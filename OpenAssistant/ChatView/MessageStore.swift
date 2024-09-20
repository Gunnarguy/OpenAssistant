import Foundation
import Combine
import SwiftUI

class MessageStore: ObservableObject {
    @Published var messages: [Message] = []
    private let userDefaultsKey = "savedMessages"

    init() {
        loadMessages()
    }

    func addMessage(_ message: Message) {
        messages.append(message)
        saveMessages()
    }

    func addMessages(_ newMessages: [Message]) {
        messages.append(contentsOf: newMessages)
        saveMessages()
    }

    private func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadMessages() {
        if let savedMessages = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decodedMessages = try? JSONDecoder().decode([Message].self, from: savedMessages) {
            messages = decodedMessages
        }
    }
}
