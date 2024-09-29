import Foundation
import Combine
import SwiftUI

@MainActor
class AssistantPickerViewModel: BaseViewModel {
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
            self?.handleFetchResult(result)
        }
    }

    func selectAssistant(_ assistant: Assistant) {
        selectedAssistant = assistant
        navigateToChat = true
    }

    // MARK: - Private Methods
    func handleFetchResult(_ result: Result<[Assistant], OpenAIServiceError>) {
        DispatchQueue.main.async {
            switch result {
            case .success(let assistants):
                self.assistants = assistants
            case .failure(let error):
                self.handleError(IdentifiableError(message: error.localizedDescription))
            }
            self.isLoading = false
        }
    }

    func setupNotificationObservers() {
        let notificationCenter = NotificationCenter.default
        let notifications: [Notification.Name] = [.assistantCreated, .assistantUpdated, .assistantDeleted, .settingsUpdated]

        notifications.forEach { notification in
            notificationCenter.publisher(for: notification)
                .sink { [weak self] _ in self?.fetchAssistants() }
                .store(in: &cancellables)
        }
    }
}

extension Notification.Name {
    static let settingsUpdated = Notification.Name("settingsUpdated")
}
