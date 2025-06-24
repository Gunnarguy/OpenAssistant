import Combine
import Foundation

@MainActor
class AssistantPickerViewModel: BaseAssistantViewModel {
    @Published var assistants: [Assistant] = []
    @Published var isLoading = true

    override init() {
        super.init()
        // Removed fetchAssistants() from init. It will be called by the View's .task modifier.
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

        // Notifications that trigger a full refetch
        let refetchNotifications: [Notification.Name] = [
            .assistantCreated, .assistantDeleted, .didUpdateAssistant, .settingsUpdated,
        ]

        for notificationName in refetchNotifications {
            notificationCenter.publisher(for: notificationName)
                .sink { [weak self] _ in self?.fetchAssistants() }
                .store(in: &cancellables)
        }

        // Handle assistant updates more efficiently
        notificationCenter.publisher(for: .assistantUpdated)
            .sink { [weak self] notification in
                guard let self = self, let updatedAssistant = notification.object as? Assistant
                else {
                    // Fallback to refetch if the object is not available
                    self?.fetchAssistants()
                    return
                }

                // Update the specific assistant in the list
                if let index = self.assistants.firstIndex(where: { $0.id == updatedAssistant.id }) {
                    self.assistants[index] = updatedAssistant
                } else {
                    // If not found, it might be a new assistant, so refetch all
                    self.fetchAssistants()
                }
            }
            .store(in: &cancellables)
    }
}
