import Foundation
import Combine

@MainActor
class AssistantPickerViewModel: BaseAssistantViewModel {
    @Published var assistants: [Assistant] = []
    @Published var selectedAssistant: Assistant?
    @Published var isLoading = true
    @Published var navigateToChat = false

    override init() {
        super.init()
        fetchAssistants()
        setupNotificationObservers()
    }

    // MARK: - Public Methods
    func fetchAssistants() {
        guard let openAIService = openAIService else {
            handleError(IdentifiableError(message: "OpenAIService is not initialized."))
            return
        }

        isLoading = true
        errorMessage = nil

        openAIService.fetchAssistants { [weak self] result in
            guard let self = self else { return }
            self.handleResult(result) { assistants in
                self.assistants = assistants
                self.isLoading = false
            }
        }
    }

    func selectAssistant(_ assistant: Assistant) {
        selectedAssistant = assistant
        navigateToChat = true
    }

    // MARK: - Override Notification Observers
    override func setupNotificationObservers() {
        super.setupNotificationObservers()
        let notificationCenter = NotificationCenter.default
        let notifications: [Notification.Name] = [.assistantCreated, .assistantUpdated, .assistantDeleted, .settingsUpdated]

        notifications.forEach { notification in
            notificationCenter.publisher(for: notification)
                .sink { [weak self] _ in self?.fetchAssistants() }
                .store(in: &cancellables)
        }
    }
}
