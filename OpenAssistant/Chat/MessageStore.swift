import Foundation
import Combine
import SwiftUI

class MessageStore: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [Message] = []

    // MARK: - Private Properties
    private let userDefaultsKey = "savedMessages"

    // MARK: - Initializer
    init() {
        loadMessages()
    }

    // MARK: - Public Methods
    func addMessage(_ message: Message) {
        messages.append(message)
        saveMessages()
    }

    func addMessages(_ newMessages: [Message]) {
        messages.append(contentsOf: newMessages)
        saveMessages()
    }

    // MARK: - Private Methods
    private func saveMessages() {
        do {
            let encoded = try JSONEncoder().encode(messages)
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        } catch {
            print("Failed to encode messages: \(error.localizedDescription)")
        }
    }

    private func loadMessages() {
        guard let savedMessages = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            messages = try JSONDecoder().decode([Message].self, from: savedMessages)
        } catch {
            print("Failed to decode messages: \(error.localizedDescription)")
        }
    }
}
