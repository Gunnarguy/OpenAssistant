import Combine
import Foundation
import SwiftUI

enum LoadingState: Int, CaseIterable {
    case idle = 0
    case creatingThread = 1
    case threadCreated = 2
    case runningAssistant = 3
    case processingResponse = 4
    case completingRun = 5
    case sendingMessage = 6

    var description: String {
        switch self {
        case .idle: return "Ready"
        case .creatingThread: return "Creating Thread"
        case .threadCreated: return "Thread Created"
        case .runningAssistant: return "Running Assistant"
        case .processingResponse: return "Processing"
        case .completingRun: return "Completing"
        case .sendingMessage: return "Sending Message"
        }
    }
}

@MainActor
class ChatViewModel: BaseViewModel {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isLoading = false
    @Published var stepCounter: Int = 0
    @Published var loadingState: LoadingState = .idle
    @Published var shouldFocusTextField: Bool = false  // Add state to control focus

    // Expose the thread ID as a computed property
    var threadId: String? {
        // Add logging here to see what the computed property returns
        let id = thread?.id
        print("ChatViewModel: Computed threadId is \(id ?? "nil")")
        return id
    }

    // Remove 'weak' keyword as ScrollViewProxy is not a class type
    var scrollViewProxy: ScrollViewProxy?
    let assistant: Assistant
    private var thread: Thread?
    private var hasCreatedThread = false
    private var messageStore: MessageStore

    init(assistant: Assistant, messageStore: MessageStore) {
        self.assistant = assistant
        self.messageStore = messageStore
        super.init()
        print("ChatViewModel init: Assistant ID \(assistant.id)")

        // Always create a new thread for a new chat session.
        // Remove the logic that checked assistant.threads
        print("ChatViewModel init: Creating a new thread for this chat session.")
        createThread()
    }

    private func fetchMessagesForThread(threadId: String) {
        updateLoadingState(isLoading: true, state: .processingResponse)
        openAIService?.fetchRunMessages(threadId: threadId) { [weak self] result in
            Task { @MainActor in
                self?.handleFetchMessagesResult(result)
                self?.updateLoadingState(isLoading: false)
            }
        }
    }

    // MARK: - Thread Management

    func createThread() {
        // Remove the guard check, as we always want to create one now on init
        // guard !hasCreatedThread else { return }
        updateLoadingState(isLoading: true, state: .creatingThread)
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
            // Set hasCreatedThread after successful creation
            self.hasCreatedThread = true
            // Add logging here to confirm thread assignment
            print("ChatViewModel: Successfully created and assigned thread ID \(thread.id)")
            // Don't load messages from the new thread, it will be empty initially
            // self.messages = thread.messages ?? []
            // messageStore.addMessages(thread.messages ?? [])
            stepCounter = 2
            print("Thread created successfully: \(thread.id)")  // Keep original log too
        case .failure(let error):
            // Add logging here to see the failure
            print("ChatViewModel: Failed to create thread - \(error.localizedDescription)")
            handleError(error)
            // Ensure hasCreatedThread remains false on failure
            self.hasCreatedThread = false
        }
    }

    func runAssistantOnThread() {
        guard let thread = thread else { return }
        updateLoadingState(isLoading: true, state: .runningAssistant)
        print("Running assistant on thread: \(thread.id)")

        openAIService?.runAssistantOnThread(threadId: thread.id, assistantId: assistant.id) {
            [weak self] result in
            Task { @MainActor in
                self?.handleRunAssistantResult(result, threadId: thread.id)
            }
        }
    }

    private func handleRunAssistantResult(
        _ result: Result<Run, OpenAIServiceError>, threadId: String
    ) {
        updateLoadingState(isLoading: false)
        switch result {
        case .success(let run):
            print("Assistant run on thread successfully: \(run.id)")
            stepCounter = 4
            pollRunStatus(threadId: threadId, runId: run.id)
        case .failure(let error):
            handleError(error)
        }
    }

    // MARK: - Polling

    func pollRunStatus(threadId: String, runId: String) {
        let pollingInterval: TimeInterval = 2.0
        updateLoadingState(isLoading: true)

        // Explicitly schedule timer on the main run loop in default mode
        let timer = Timer(timeInterval: pollingInterval, repeats: true) { [weak self] timer in
            // Callback still uses Task @MainActor for safety
            Task { @MainActor in
                self?.checkRunStatus(threadId: threadId, runId: runId, timer: timer)
            }
        }
        RunLoop.main.add(timer, forMode: .default)

        // Keep a reference to the timer if you need to invalidate it elsewhere later
        // self.pollingTimer = timer // (Requires adding a 'pollingTimer' property)
    }

    private func checkRunStatus(threadId: String, runId: String, timer: Timer) {
        Task {
            do {
                let run = try await fetchRunStatus(threadId: threadId, runId: runId)
                await MainActor.run {
                    handleRunStatus(run, timer: timer)
                }
            } catch {
                await MainActor.run {
                    if let openAIError = error as? OpenAIServiceError {
                        handleError(openAIError)
                    } else {
                        handleError("Failed to fetch run status: \(error.localizedDescription)")
                    }
                    timer.invalidate()
                    updateLoadingState(isLoading: false)
                }
            }
        }
    }

    private func handleRunStatus(_ run: Run, timer: Timer) {
        print("Run status: \(run.status)")
        if run.status == "completed" {
            handleRunCompletion(run)
            timer.invalidate()
            DispatchQueue.main.async {
                self.updateLoadingState(isLoading: false, state: .completingRun)
            }
        } else if run.status == "failed" {
            handleError("Run failed.")
            timer.invalidate()
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
        case .success(let fetchedMessages):
            // Filter only assistant messages from the fetch result
            let assistantMessages = fetchedMessages.filter { $0.role == .assistant }

            // Find messages that are not already present in the local 'messages' array
            let newMessages = assistantMessages.filter { newMessage in
                !self.messages.contains(where: { $0.id == newMessage.id })
            }

            // Only append if there are actually new messages
            if !newMessages.isEmpty {
                // Prepend new messages because the list is visually reversed
                self.messages.insert(contentsOf: newMessages, at: 0)
                // Add to the central store as well
                messageStore.addMessages(newMessages)
                // Scroll after adding new messages
                scrollToLastMessage(animated: true)
            }
        case .failure(let error):
            handleError(error)
        }
        // Ensure loading state is updated regardless of success/failure or new messages found
        updateLoadingState(isLoading: false)
    }

    // MARK: - Sending Messages

    func sendMessage() {
        guard let thread = thread, !inputText.isEmpty else { return }
        let textToSend = inputText  // Capture text before clearing
        inputText = ""  // Clear input field immediately

        let userMessage = createUserMessage(threadId: thread.id, content: textToSend)

        // Prepend user message because the list is visually reversed
        messages.insert(userMessage, at: 0)
        messageStore.addMessage(userMessage)  // Add to central store
        updateLoadingState(isLoading: true, state: .sendingMessage)
        scrollToLastMessage(animated: true)  // Scroll to show the new user message

        // Dismiss keyboard
        Task { @MainActor in
            shouldFocusTextField = false
        }

        print("Sending message: \(userMessage.content.first?.text?.value ?? "empty")")

        openAIService?.addMessageToThread(threadId: thread.id, message: userMessage) {
            [weak self] result in
            Task { @MainActor in
                self?.handleSendMessageResult(result)
            }
        }
    }

    // Updated to accept content directly
    private func createUserMessage(threadId: String, content: String) -> Message {
        let uniqueID = generateUniqueMessageID()
        return Message(
            id: uniqueID,
            object: "thread.message",
            created_at: Int(Date().timeIntervalSince1970),
            assistant_id: nil,
            thread_id: threadId,
            run_id: nil,
            role: .user,
            content: [
                Message.Content(type: "text", text: Message.Text(value: content, annotations: []))  // Use passed content
            ],
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
            handleError(error)
        }
    }

    // MARK: - UI Updates

    // Updated scrollToLastMessage to handle reversed list and animation
    func scrollToLastMessage(animated: Bool = true) {
        guard let scrollViewProxy = scrollViewProxy, let firstMessage = messages.first else {
            // If no messages, maybe scroll to a bottom anchor if one exists
            // Or if proxy exists, scroll to the "bottomSpacer" ID
            if let proxy = scrollViewProxy {
                DispatchQueue.main.async {  // Ensure UI updates on main thread
                    withAnimation(animated ? .spring() : nil) {
                        proxy.scrollTo("bottomSpacer", anchor: .bottom)
                    }
                }
            }
            return
        }

        // Scroll to the ID of the *first* message in the array (which is visually the last)
        DispatchQueue.main.async {  // Ensure UI updates on main thread
            withAnimation(animated ? .spring() : nil) {  // Use spring animation or none
                scrollViewProxy.scrollTo(firstMessage.id, anchor: .bottom)  // Anchor to bottom
            }
        }
    }

    // Add a safe setter method for the scrollViewProxy
    func setScrollViewProxy(_ proxy: ScrollViewProxy?) {
        self.scrollViewProxy = proxy
    }

    // MARK: - Error Handling

    private func handleError(_ message: String) {
        Task { @MainActor in
            self.errorMessage = IdentifiableError(message: message)
            self.hasCreatedThread = false
            updateLoadingState(isLoading: false)
        }
    }

    private func handleError(_ error: OpenAIServiceError) {
        Task { @MainActor in
            // Add logging here
            print("ChatViewModel: Handling OpenAI Service Error - \(error.localizedDescription)")
            self.errorMessage = IdentifiableError(message: error.localizedDescription)
            self.hasCreatedThread = false
            updateLoadingState(isLoading: false)
        }
    }

    // MARK: - Utility

    private func updateLoadingState(isLoading: Bool, state: LoadingState? = nil) {
        self.isLoading = isLoading
        if let state = state {
            self.loadingState = state
            self.stepCounter = state.rawValue
        } else if !isLoading {
            self.loadingState = .idle
            self.stepCounter = 0
        }
    }
}
