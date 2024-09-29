import Foundation
import Combine
import SwiftUI

/// A store that manages chat messages, providing functionality to add, save, and load messages.
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

    /// Adds a single message to the store and saves the updated list of messages.
    /// - Parameter message: The message to be added.
    func addMessage(_ message: Message) {
        messages.append(message)
        saveMessages()
    }

    /// Adds multiple messages to the store and saves the updated list of messages.
    /// - Parameter newMessages: The messages to be added.
    func addMessages(_ newMessages: [Message]) {
        messages.append(contentsOf: newMessages)
        saveMessages()
    }

    // MARK: - Private Methods

    /// Saves the current list of messages to UserDefaults.
    private func saveMessages() {
        do {
            let encoded = try JSONEncoder().encode(messages)
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        } catch {
            print("Failed to encode messages: \(error.localizedDescription)")
        }
    }

    /// Loads the list of messages from UserDefaults.
    private func loadMessages() {
        guard let savedMessages = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            messages = try JSONDecoder().decode([Message].self, from: savedMessages)
        } catch {
            print("Failed to decode messages: \(error.localizedDescription)")
        }
    }
}
