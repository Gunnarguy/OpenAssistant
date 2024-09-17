import Foundation
import Combine
import SwiftUI

class AssistantPickerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var assistants: [Assistant] = []
    @Published var selectedAssistant: Assistant?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var navigateToChat = false

    // MARK: - Private Properties
    private lazy var openAIService = OpenAIService(apiKey: apiKey)
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""

    // MARK: - Initializer
    init() {
        fetchAssistants()
    }

    // MARK: - Public Methods
    func fetchAssistants() {
        isLoading = true
        errorMessage = nil

        openAIService.fetchAssistants { [weak self] result in
            DispatchQueue.main.async {
                self?.handleFetchResult(result)
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
            self.errorMessage = getErrorMessage(for: error)
        }
        self.isLoading = false
    }

    private func getErrorMessage(for error: OpenAIServiceError) -> String {
        switch error {
        case .apiKeyMissing:
            return "API key is missing."
        case .noData:
            return "No data received from the server."
        case .decodingError(_, let decodingError):
            return "Failed to decode response: \(decodingError.localizedDescription)"
        case .networkError(let networkError):
            return "Network Error: \(networkError.localizedDescription)"
        case .invalidResponse(let response):
            return "Invalid response received: \(response)"
        default:
            return "An unknown error occurred."
        }
    }
}

