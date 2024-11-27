import Foundation
import Combine
import SwiftUI

@MainActor
class BaseViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var errorMessage: IdentifiableError?
    
    // MARK: - Stored Properties
    @AppStorage("OpenAI_API_Key") private var storedApiKey: String = "" {
        didSet {
            initializeOpenAIService()
        }
    }
    private(set) var openAIService: OpenAIService?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer
    init() {
        initializeOpenAIService()
        setupNotificationObservers()
    }

    // MARK: - Service Initialization
    /// Initializes or updates the OpenAI service based on the stored API key.
    private func initializeOpenAIService() {
        if storedApiKey.isEmpty {
            openAIService = nil
            print("API key is empty. OpenAI service is not initialized.")
        } else {
            openAIService = OpenAIServiceInitializer.initialize(apiKey: storedApiKey)
            print("OpenAI service initialized with the provided API key.")
        }
    }

    // MARK: - Error Handling
    /// Handles errors by updating the `errorMessage` property.
    func handleError(_ error: IdentifiableError) {
        errorMessage = error
        print("Error encountered: \(error.message)")
    }

    // MARK: - Notification Observers
    /// Sets up observers for settings update notifications.
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .settingsUpdated)
            .sink { [weak self] _ in
                self?.initializeOpenAIService()
            }
            .store(in: &cancellables)
    }

    // MARK: - Access API Key
    /// Provides read-only access to the API key.
    var apiKey: String {
        storedApiKey
    }
}
