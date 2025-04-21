import Combine
import Foundation
import SwiftUI

@MainActor
class BaseViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var errorMessage: IdentifiableError?

    // MARK: - Stored Properties
    @AppStorage("OpenAI_API_Key") private var storedApiKey: String = ""
    private(set) var openAIService: OpenAIService?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var apiKey: String {
        storedApiKey
    }

    // MARK: - Initialization
    init() {
        initializeOpenAIService()
        setupNotificationObservers()
    }

    // MARK: - Service Initialization
    func initializeOpenAIService() {
        guard !storedApiKey.isEmpty else {
            openAIService = nil
            logMessage("API key is empty. OpenAI service is not initialized.")
            return
        }
        openAIService = OpenAIServiceInitializer.initialize(apiKey: storedApiKey)
        logMessage("OpenAI service initialized with the provided API key.")
    }

    // MARK: - Error Handling
    func handleError(_ error: IdentifiableError) {
        errorMessage = error
        logMessage("Error encountered: \(error.message)", isError: true)
    }

    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .settingsUpdated)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleSettingsUpdated()
                }
            }
            .store(in: &cancellables)
    }

    private func handleSettingsUpdated() {
        initializeOpenAIService()
        logMessage("Settings updated notification received.")
    }

    // MARK: - Logging
    nonisolated private func logMessage(_ message: String, isError: Bool = false) {
        #if DEBUG
            let prefix = isError ? "ERROR: " : "INFO: "
            print("\(prefix)\(message)")
        #endif
    }

    // MARK: - API Key Observer
    private func didSetApiKey() {
        guard !storedApiKey.isEmpty else {
            logMessage("Updated API key is empty. Clearing OpenAI service.", isError: true)
            openAIService = nil
            return
        }
        openAIService = OpenAIServiceInitializer.initialize(apiKey: storedApiKey)
        logMessage("API key updated. OpenAI service reinitialized.")
    }

    // MARK: - Deinitializer
    deinit {
        cancellables.removeAll()
        logMessage("BaseViewModel deinitialized. Observers cleared.")
    }

    // MARK: - Model Parameter Support Helper

    /// Checks if a model is an O-series reasoning model.
    static func isReasoningModel(_ modelId: String) -> Bool {
        let lowercasedModel = modelId.lowercased()
        return lowercasedModel.starts(with: "o1") || lowercasedModel.starts(with: "o3")
            || lowercasedModel.starts(with: "o4")
    }

    /// Checks if a model supports temperature/top_p settings at the Assistant level.
    /// Reasoning models (o-series) use reasoning_effort instead.
    static func supportsTempTopPAtAssistantLevel(_ modelId: String) -> Bool {
        // Models that are NOT reasoning models support temp/top_p at this level.
        return !isReasoningModel(modelId.lowercased())
    }
}

// MARK: - Result Handling
extension BaseViewModel {
    func handleResult<T>(_ result: Result<T, OpenAIServiceError>, success: @escaping (T) -> Void) {
        switch result {
        case .success(let value):
            success(value)
        case .failure(let error):
            let errorMessage = "Operation failed: \(error.localizedDescription)"
            handleError(IdentifiableError(message: errorMessage))
        }
    }

    func performServiceAction(_ action: (OpenAIService) -> Void) {
        guard let service = openAIService else {
            handleError(IdentifiableError(message: "OpenAIService is not initialized"))
            return
        }
        action(service)
    }
}
