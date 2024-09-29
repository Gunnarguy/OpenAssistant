import Foundation
import Combine
import SwiftUI

@MainActor
class BaseAssistantViewModel: ObservableObject {
    @Published var errorMessage: String?
    var openAIService: OpenAIService?
    var cancellables = Set<AnyCancellable>()

    // Fetch API Key from UserDefaults or AppStorage
    var apiKey: String {
        UserDefaults.standard.string(forKey: "OpenAI_API_Key") ?? ""
    }

    init() {
        initializeOpenAIService()
    }

    func initializeOpenAIService() {
        openAIService = OpenAIServiceInitializer.initialize(apiKey: apiKey)
        if openAIService == nil {
            handleError("API key is missing")
        }
    }

    func performServiceAction(action: (OpenAIService) -> Void) {
        guard let openAIService = openAIService else {
            handleError("OpenAIService is not initialized")
            return
        }
        action(openAIService)
    }

    func handleError(_ message: String) {
        errorMessage = message
    }

    func handleResult<T>(_ result: Result<T, OpenAIServiceError>, successHandler: @escaping (T) -> Void) {
        DispatchQueue.main.async {
            switch result {
            case .success(let value):
                successHandler(value)
            case .failure(let error):
                self.handleError("Operation failed: \(error.localizedDescription)")
            }
        }
    }
}
