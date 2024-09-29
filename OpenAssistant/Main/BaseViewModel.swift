import Foundation
import Combine
import SwiftUI

@MainActor
class BaseViewModel: ObservableObject {
    @Published var errorMessage: IdentifiableError?
    @AppStorage("OpenAI_API_Key") var apiKey: String = ""
    var openAIService: OpenAIService?
    var cancellables = Set<AnyCancellable>()

    init() {
        initializeOpenAIService()
        setupNotificationObservers()
    }

    // MARK: - Service Initialization
    func initializeOpenAIService() {
        guard !apiKey.isEmpty else {
            handleError(IdentifiableError(message: "API key is missing"))
            return
        }
        openAIService = OpenAIServiceInitializer.initialize(apiKey: apiKey)
    }

    // MARK: - Error Handling
    func handleError(_ error: IdentifiableError) {
        errorMessage = error
    }

    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .settingsUpdated)
            .sink { [weak self] _ in
                self?.updateApiKey()
            }
            .store(in: &cancellables)
    }

    // MARK: - Update API Key
    private func updateApiKey() {
        openAIService = OpenAIServiceInitializer.reinitialize(apiKey: apiKey)
    }
}
