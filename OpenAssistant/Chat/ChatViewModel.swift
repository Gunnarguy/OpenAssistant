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
        updateLoadingState(isLoading: true, step: 1)
        print("Creating thread...")

        openAIService?.createThread { [weak self] result in
            Task { @MainActor in
                self?.handleCreateThreadResult(result)
            }
        }
    }

    private func handleCreateThreadResult(_ result: Result<Thread, OpenAIServiceError>) {
        updateLoadingState(isLoading: false)
        switch result {
        case .success(let thread):
            self.thread = thread
            self.messages = thread.messages ?? []
            messageStore.addMessages(thread.messages ?? [])
            stepCounter = 2
            print("Thread created successfully: \(thread.id)")
        case .failure(let error):
            handleError("Failed to create thread: \(error.localizedDescription)")
        }
    }

    func runAssistantOnThread() {
        guard let thread = thread else { return }
        updateLoadingState(isLoading: true, step: 3)
        print("Running assistant on thread: \(thread.id)")

        openAIService?.runAssistantOnThread(threadId: thread.id, assistantId: assistant.id) { [weak self] result in
            Task { @MainActor in
                self?.handleRunAssistantResult(result, threadId: thread.id)
            }
        }
    }

    private func handleRunAssistantResult(_ result: Result<Run, OpenAIServiceError>, threadId: String) {
        updateLoadingState(isLoading: false)
        switch result {
        case .success(let run):
            print("Assistant run on thread successfully: \(run.id)")
            stepCounter = 4
            pollRunStatus(threadId: threadId, runId: run.id)
        case .failure(let error):
            handleError("Failed to run assistant on thread: \(error.localizedDescription)")
        }
    }

    // MARK: - Polling

    func pollRunStatus(threadId: String, runId: String) {
        let pollingInterval: TimeInterval = 2.0
        updateLoadingState(isLoading: true)

        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now(), repeating: pollingInterval)

        timer.setEventHandler { [weak self] in
            self?.checkRunStatus(threadId: threadId, runId: runId, timer: timer)
        }

        timer.resume()
    }

    private func checkRunStatus(threadId: String, runId: String, timer: DispatchSourceTimer) {
        Task {
            do {
                let run = try await fetchRunStatus(threadId: threadId, runId: runId)
                await MainActor.run {
                    handleRunStatus(run, timer: timer)
                }
            } catch {
                await MainActor.run {
                    handleError("Failed to fetch run status: \(error.localizedDescription)")
                    timer.cancel()
                    updateLoadingState(isLoading: false)
                }
            }
        }
    }

    private func handleRunStatus(_ run: Run, timer: DispatchSourceTimer) {
        print("Run status: \(run.status)")
        if run.status == "completed" {
            handleRunCompletion(run)
            timer.cancel()
            updateLoadingState(isLoading: false, step: 5)
        } else if run.status == "failed" {
            handleError("Run failed.")
            timer.cancel()
            updateLoadingState(isLoading: false)
        }
    }

    private func fetchRunStatus(threadId: String, runId: String) async throws -> Run {
        try await withCheckedThrowingContinuation { continuation in
            openAIService?.fetchRunStatus(threadId: threadId, runId: runId) { result in
                continuation.resume(with: result)
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
                self?.handleFetchMessagesResult(result)
            }
        }
    }

    private func handleFetchMessagesResult(_ result: Result<[Message], OpenAIServiceError>) {
        switch result {
        case .success(let messages):
            let assistantMessages = messages.filter { $0.role == .assistant }
            let newMessages = assistantMessages.filter { newMessage in
                !self.messages.contains(where: { $0.id == newMessage.id })
            }
            self.messages.append(contentsOf: newMessages)
            messageStore.addMessages(newMessages)
            scrollToLastMessage()
        case .failure(let error):
            handleError("Failed to fetch messages: \(error.localizedDescription)")
        }
    }

    // MARK: - Sending Messages

    func sendMessage() {
        guard let thread = thread, !inputText.isEmpty else { return }

        let userMessage = createUserMessage(threadId: thread.id)
        print("Message IDs before adding new message:")
        messages.forEach { print($0.id) }

        messages.append(userMessage)
        messageStore.addMessage(userMessage)
        checkForDuplicateIDs()
        inputText = ""
        updateLoadingState(isLoading: true, step: 6)

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        print("Sending message: \(userMessage.content)")

        openAIService?.addMessageToThread(threadId: thread.id, message: userMessage) { [weak self] result in
            Task { @MainActor in
                self?.handleSendMessageResult(result)
            }
        }
    }

    private func createUserMessage(threadId: String) -> Message {
        let uniqueID = UUID().uuidString
        return Message(
            id: uniqueID,
            object: "thread.message",
            created_at: Int(Date().timeIntervalSince1970),
            assistant_id: nil,
            thread_id: threadId,
            run_id: nil,
            role: .user,
            content: [Message.Content(type: "text", text: Message.Text(value: inputText, annotations: []))],
            attachments: [],
            metadata: [:]
        )
    }

    private func generateUniqueMessageID() -> String {
        var uniqueID = UUID().uuidString
        while messages.contains(where: { $0.id == uniqueID }) {
            uniqueID = UUID().uuidString
        }
        return uniqueID
    }

    private func handleSendMessageResult(_ result: Result<Void, OpenAIServiceError>) {
        switch result {
        case .success:
            print("Message sent successfully.")
            runAssistantOnThread()
        case .failure(let error):
            updateLoadingState(isLoading: false)
            handleError("Failed to send message: \(error.localizedDescription)")
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
            updateLoadingState(isLoading: false)
        }
    }

    // MARK: - Utility

    private func checkForDuplicateIDs() {
        let ids = messages.map { $0.id }
        let duplicates = Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.keys
        if !duplicates.isEmpty {
            print("Duplicate IDs found: \(duplicates)")
        } else {
            print("All IDs are unique.")
        }
    }

    private func updateLoadingState(isLoading: Bool, step: Int? = nil) {
        self.isLoading = isLoading
        if let step = step {
            self.stepCounter = step
        }
    }
}
