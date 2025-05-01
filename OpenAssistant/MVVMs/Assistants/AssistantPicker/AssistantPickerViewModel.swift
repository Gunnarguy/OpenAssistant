import Combine
import Foundation

@MainActor
class AssistantPickerViewModel: BaseAssistantViewModel {
    @Published var assistants: [Assistant] = []
    @Published var isLoading = true

    override init() {
        super.init()
        fetchAssistants()
        setupNotificationObservers()
    }

    // MARK: - Public Methods
    func fetchAssistants() {
        guard let openAIService = openAIService else {
            // Stop loading and show error if service isn't initialized (e.g., missing API key).
            isLoading = false
            handleError(
                IdentifiableError(
                    message:
                        "OpenAIService is not initialized. Please set your API key in Settings."))
            return
        }

        isLoading = true
        errorMessage = nil

        openAIService.fetchAssistants { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.handleResult(result) { assistants in
                    self.assistants = assistants
                    self.isLoading = false
                }
                if self.errorMessage != nil {
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Override Notification Observers
    override func setupNotificationObservers() {
        super.setupNotificationObservers()
        let notificationCenter = NotificationCenter.default
        let notifications: [Notification.Name] = [
            .assistantCreated, .assistantUpdated, .assistantDeleted, .settingsUpdated,
        ]

        notifications.forEach { notification in
            notificationCenter.publisher(for: notification)
                .sink { [weak self] _ in self?.fetchAssistants() }
                .store(in: &cancellables)
        }
    }
}
