import Combine
import Foundation
import SwiftUI

/// A store that manages chat messages, providing functionality to add, save, and load messages.
class MessageStore: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [Message] = []
    @AppStorage("savedMessages") private var savedMessagesData: Data?

    // MARK: - Initializer
    init() {
        loadMessages()
    }

    // MARK: - Public Methods

    /// Adds a single message to the store if it doesn't already exist and saves the updated list.
    /// - Parameter message: The message to be added.
    func addMessage(_ message: Message) {
        // Check if a message with the same ID already exists
        guard !messages.contains(where: { $0.id == message.id }) else {
            print("MessageStore: Message ID \(message.id) already exists. Skipping add.")
            return
        }
        // Log adding a single message with its thread ID
        print("MessageStore: Adding message ID \(message.id) for thread \(message.thread_id)")
        messages.append(message)
        saveMessages()
    }

    /// Adds multiple messages to the store, filtering out duplicates, and saves the updated list.
    /// - Parameter newMessages: The messages to be added.
    func addMessages(_ newMessages: [Message]) {
        // Filter out messages that already exist in the store based on ID
        let messagesToAdd = newMessages.filter { newMessage in
            !self.messages.contains(where: { $0.id == newMessage.id })
        }

        guard !messagesToAdd.isEmpty else {
            print(
                "MessageStore: All \(newMessages.count) messages already exist or input was empty. Skipping add."
            )
            return
        }

        // Log adding multiple messages and their thread IDs
        print(
            "MessageStore: Adding \(messagesToAdd.count) new messages (filtered from \(newMessages.count))."
        )
        for message in messagesToAdd {
            print("  - Adding message ID \(message.id) for thread \(message.thread_id)")
        }
        messages.append(contentsOf: messagesToAdd)
        saveMessages()
    }

    // MARK: - Private Methods

    /// Saves the current list of messages to UserDefaults.
    private func saveMessages() {
        // Log the save operation and the thread IDs involved
        print("MessageStore: Saving \(messages.count) total messages.")
        let threadIDs = Set(messages.map { $0.thread_id })
        print("MessageStore: Saving messages for thread IDs: \(threadIDs)")
        do {
            let encoded = try JSONEncoder().encode(messages)
            savedMessagesData = encoded
            // Log successful save
            print("MessageStore: Save successful.")
        } catch {
            // Log encoding errors
            print("MessageStore: Failed to encode messages: \(error.localizedDescription)")
        }
    }

    /// Loads the list of messages from UserDefaults.
    private func loadMessages() {
        guard let data = savedMessagesData else {
            // Log if no saved data is found
            print("MessageStore: No saved messages data found.")
            return
        }
        // Log the attempt to load data
        print("MessageStore: Found saved messages data (\(data.count) bytes). Attempting to load.")
        do {
            messages = try JSONDecoder().decode([Message].self, from: data)
            // Log successful load and the thread IDs found
            print("MessageStore: Successfully loaded \(messages.count) messages.")
            let threadIDs = Set(messages.map { $0.thread_id })
            print("MessageStore: Loaded messages for thread IDs: \(threadIDs)")
        } catch {
            // Log decoding errors
            print("MessageStore: Failed to decode messages: \(error.localizedDescription)")
        }
    }
}
