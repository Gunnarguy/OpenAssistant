import Foundation
import Combine
import SwiftUI

@MainActor
class BaseAssistantViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var errorMessage: IdentifiableError?
    
    // MARK: - Stored Properties
    var openAIService: OpenAIService?
    var cancellables = Set<AnyCancellable>()
    @AppStorage("OpenAI_API_Key") private var apiKey: String = "" {
        didSet {
            updateApiKey()
        }
    }

    // MARK: - Initializer
    init() {
        initializeOpenAIService()
        setupNotificationObservers()
    }

    // MARK: - Service Initialization
    func initializeOpenAIService() {
        guard !apiKey.isEmpty else {
            return
        }
        openAIService = OpenAIServiceInitializer.initialize(apiKey: apiKey)
    }

    // MARK: - Perform Service Action
    func performServiceAction(action: (OpenAIService) -> Void) {
        guard let openAIService = openAIService else {
            handleError(IdentifiableError(message: "OpenAIService is not initialized"))
            return
        }
        action(openAIService)
    }

    // MARK: - Handle Result
    func handleResult<T>(_ result: Result<T, OpenAIServiceError>, successHandler: @escaping (T) -> Void) {
        switch result {
        case .success(let value):
            successHandler(value)
        case .failure(let error):
            handleError(IdentifiableError(message: "Operation failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - Error Handling
    func handleError(_ error: IdentifiableError) {
        errorMessage = error
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
    private func updateApiKey(newApiKey: String? = nil) {
        if let newApiKey = newApiKey {
            UserDefaults.standard.set(newApiKey, forKey: "OpenAI_API_Key")
        }
        openAIService = OpenAIServiceInitializer.initialize(apiKey: apiKey)
    }
}
