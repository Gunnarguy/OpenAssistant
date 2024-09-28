import Foundation
import Combine
import SwiftUI

@MainActor
class ChatViewModel: BaseViewModel {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isLoading = false
    @Published var stepCounter: Int = 0

    var scrollViewProxy: ScrollViewProxy?
    let assistant: Assistant
    private var thread: Thread?
    private var hasCreatedThread = false
    private var messageStore: MessageStore

    init(assistant: Assistant, messageStore: MessageStore) {
        self.assistant = assistant
        self.messageStore = messageStore
        super.init()
        createThread()
    }

    // MARK: - Thread Management

    func createThread() {
        guard !hasCreatedThread else { return }
        hasCreatedThread = true
        isLoading = true
        stepCounter = 1
        print("Creating thread...")

        openAIService?.createThread { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                switch result {
                case .success(let thread):
                    self?.thread = thread
                    self?.messages = thread.messages ?? []
                    self?.messageStore.addMessages(thread.messages ?? [])
                    self?.stepCounter = 2
                    print("Thread created successfully: \(thread.id)")
                case .failure(let error):
                    print("Failed to create thread: \(error.localizedDescription)")
                    self?.handleError("Failed to create thread: \(error.localizedDescription)")
                }
            }
        }
    }

    func runAssistantOnThread() {
        guard let thread = thread else { return }
        isLoading = true
        stepCounter = 3
        print("Running assistant on thread: \(thread.id)")

        openAIService?.runAssistantOnThread(threadId: thread.id, assistantId: assistant.id) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                switch result {
                case .success(let run):
                    print("Assistant run on thread successfully: \(run.id)")
                    self?.stepCounter = 4
                    self?.pollRunStatus(threadId: thread.id, runId: run.id)
                case .failure(let error):
                    print("Failed to run assistant on thread: \(error.localizedDescription)")
                    self?.handleError("Failed to run assistant on thread: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Polling

    func pollRunStatus(threadId: String, runId: String) {
        let pollingInterval: TimeInterval = 2.0
        isLoading = true

        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now(), repeating: pollingInterval)

        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task {
                do {
                    let run = try await self.fetchRunStatus(threadId: threadId, runId: runId)
                    await MainActor.run {
                        print("Run status: \(run.status)")
                        if run.status == "completed" {
                            self.handleRunCompletion(run)
                            timer.cancel()
                            self.isLoading = false
                            self.stepCounter = 5
                        } else if run.status == "failed" {
                            self.handleError("Run failed.")
                            timer.cancel()
                            self.isLoading = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.handleError("Failed to fetch run status: \(error.localizedDescription)")
                        timer.cancel()
                        self.isLoading = false
                    }
                }
            }
        }

        timer.resume()
    }

    private func fetchRunStatus(threadId: String, runId: String) async throws -> Run {
        try await withCheckedThrowingContinuation { continuation in
            openAIService?.fetchRunStatus(threadId: threadId, runId: runId) { result in
                switch result {
                case .success(let run):
                    continuation.resume(returning: run)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Run Completion

    func handleRunCompletion(_ run: Run) {
        print("Run completed: \(run)")
        fetchMessagesForRun(run)
    }

    func fetchMessagesForRun(_ run: Run) {
        openAIService?.fetchRunMessages(threadId: run.thread_id) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let messages):
                    self?.messages.append(contentsOf: messages.filter { $0.role == .assistant })
                    self?.messageStore.addMessages(messages.filter { $0.role == .assistant })
                    self?.scrollToLastMessage()
                case .failure(let error):
                    print("Failed to fetch messages: \(error.localizedDescription)")
                    self?.handleError("Failed to fetch messages: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Sending Messages

    func sendMessage() {
        guard let thread = thread, !inputText.isEmpty else { return }

        var uniqueID = UUID().uuidString
        while messages.contains(where: { $0.id == uniqueID }) {
            uniqueID = UUID().uuidString
        }

        let userMessage = Message(
            id: uniqueID,
            object: "thread.message",
            created_at: Int(Date().timeIntervalSince1970),
            assistant_id: nil,
            thread_id: thread.id,
            run_id: nil,
            role: .user,
            content: [Message.Content(type: "text", text: Message.Text(value: inputText, annotations: []))],
            attachments: [],
            metadata: [:]
        )

        print("Message IDs before adding new message:")
        messages.forEach { print($0.id) }

        messages.append(userMessage)
        messageStore.addMessage(userMessage)
        checkForDuplicateIDs()
        inputText = ""
        isLoading = true
        stepCounter = 6

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        print("Sending message: \(userMessage.content)")

        openAIService?.addMessageToThread(threadId: thread.id, message: userMessage) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    print("Message sent successfully.")
                    self?.runAssistantOnThread()
                case .failure(let error):
                    self?.isLoading = false
                    print("Failed to send message: \(error.localizedDescription)")
                    self?.handleError("Failed to send message: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - UI Updates

    func scrollToLastMessage() {
        if let lastMessage = messages.last {
            scrollViewProxy?.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    // MARK: - Error Handling

    private func handleError(_ message: String) {
        Task { @MainActor in
            self.errorMessage = IdentifiableError(message: message)
            self.hasCreatedThread = false
            self.isLoading = false
        }
    }

    // MARK: - Utility

    private func checkForDuplicateIDs() {
        let ids = messages.map { $0.id }
        let uniqueIDs = Set(ids)
        if ids.count != uniqueIDs.count {
            print("Duplicate IDs found!")
        } else {
            print("All IDs are unique.")
        }
    }
}
