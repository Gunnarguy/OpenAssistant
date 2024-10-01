import Foundation
import Combine
import SwiftUI

@MainActor
class BaseAssistantViewModel: ObservableObject {
    @Published var errorMessage: String?
    var openAIService: OpenAIService?
    var cancellables = Set<AnyCancellable>()

    @AppStorage("OpenAI_API_Key") private var apiKey: String = "" // Use @AppStorage

    init() {
        initializeOpenAIService()
        setupNotificationObservers()
    }

    /// Initializes the OpenAIService with the API key.
    func initializeOpenAIService() {
        guard !apiKey.isEmpty else {
            handleError("API key is missing")
            return
        }
        openAIService = OpenAIServiceInitializer.initialize(apiKey: apiKey)
    }

    func performServiceAction(action: (OpenAIService) -> Void) {
        guard let openAIService = openAIService else {
            handleError("OpenAIService is not initialized")
            return
        }
        action(openAIService)
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

    func handleError(_ message: String) {
        errorMessage = message
    }

    // MARK: - Notification Observers
    func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .settingsUpdated)
            .sink { [weak self] _ in
                self?.updateApiKey()
            }
            .store(in: &cancellables)
    }

    // MARK: - Update API Key
    func updateApiKey(newApiKey: String? = nil) {
        if let newApiKey = newApiKey {
            UserDefaults.standard.set(newApiKey, forKey: "OpenAI_API_Key")
        }
        openAIService = OpenAIServiceInitializer.reinitialize(apiKey: apiKey)
    }
}
