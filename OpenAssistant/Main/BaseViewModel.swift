import Foundation
import Combine
import SwiftUI

@MainActor
class BaseViewModel: ObservableObject {
    @Published var errorMessage: IdentifiableError?
    @AppStorage("OpenAI_API_Key") private var storedApiKey: String = ""
    var openAIService: OpenAIService?
    var cancellables = Set<AnyCancellable>()

    init() {
        initializeOpenAIService()
        setupNotificationObservers()
    }

    // MARK: - Service Initialization
    func initializeOpenAIService() {
        guard !storedApiKey.isEmpty else {
            handleError(IdentifiableError(message: "API key is missing"))
            return
        }
        openAIService = OpenAIServiceInitializer.initialize(apiKey: storedApiKey)
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
    func updateApiKey(newApiKey: String? = nil) {
        if let newApiKey = newApiKey {
            UserDefaults.standard.set(newApiKey, forKey: "OpenAI_API_Key")
            storedApiKey = newApiKey
        }
        openAIService = OpenAIServiceInitializer.reinitialize(apiKey: storedApiKey)
    }
}
