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
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.handleFetchResult(result)
            }
        }
    }

    func selectAssistant(_ assistant: Assistant) {
        selectedAssistant = assistant
        navigateToChat = true
    }

    // MARK: - Private Methods
    private func handleFetchResult(_ result: Result<[Assistant], OpenAIServiceError>) {
        switch result {
        case .success(let assistants):
            self.assistants = assistants
        case .failure(let error):
            self.handleError(IdentifiableError(message: error.localizedDescription))
        }
        self.isLoading = false
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .assistantCreated)
            .sink { [weak self] _ in self?.fetchAssistants() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .assistantUpdated)
            .sink { [weak self] _ in self?.fetchAssistants() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .assistantDeleted)
            .sink { [weak self] _ in self?.fetchAssistants() }
            .store(in: &cancellables)
        
        // Observer for the settings updated notification
        NotificationCenter.default.publisher(for: .settingsUpdated)
            .sink { [weak self] _ in self?.fetchAssistants() }
            .store(in: &cancellables)
    }
}

extension Notification.Name {
    static let settingsUpdated = Notification.Name("settingsUpdated")
}
