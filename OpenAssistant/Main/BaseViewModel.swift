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
            updateApiKey()
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
    func initializeOpenAIService() {
        guard !storedApiKey.isEmpty else {
            openAIService = nil
            print("API key is empty. OpenAI service is not initialized.")
            return
        }
        openAIService = OpenAIServiceInitializer.initialize(apiKey: storedApiKey)
        print("OpenAI service initialized with the provided API key.")
    }

    // MARK: - Error Handling
    func handleError(_ error: IdentifiableError) {
        errorMessage = error
        print("Error encountered: \(error.message)")
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
        guard !storedApiKey.isEmpty else {
            print("Updated API key is empty. Clearing OpenAI service.")
            openAIService = nil
            return
        }
        openAIService = OpenAIServiceInitializer.reinitialize(apiKey: storedApiKey)
        print("API key updated. OpenAI service reinitialized.")
    }

    // MARK: - Access API Key
    var apiKey: String {
        storedApiKey
    }

    // MARK: - Deinitializer
    deinit {
        cancellables.removeAll()
        print("BaseViewModel deinitialized. Observers cleared.")
    }
}
