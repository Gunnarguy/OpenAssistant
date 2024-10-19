import Foundation
import Combine
import SwiftUI

@MainActor
class BaseViewModel: ObservableObject {
    @Published var errorMessage: IdentifiableError?
    @AppStorage("OpenAI_API_Key") private var storedApiKey: String = "" {
        didSet {
            updateApiKey()
        }
    }
    var openAIService: OpenAIService?
    var cancellables = Set<AnyCancellable>()

    init() {
        initializeOpenAIService()
        setupNotificationObservers()
    }

    // MARK: - Service Initialization
    func initializeOpenAIService() {
        guard !storedApiKey.isEmpty else {
            
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
                self?.initializeOpenAIService()
            }
            .store(in: &cancellables)
    }

    // MARK: - Update API Key
    private func updateApiKey() {
        openAIService = OpenAIServiceInitializer.reinitialize(apiKey: storedApiKey)
    }

    // MARK: - Access API Key
    var apiKey: String {
        return storedApiKey
    }
}
