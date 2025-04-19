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

    /// Checks if a given model identifier typically supports temperature/top_p settings for generation.
    /// Note: Assistants API itself doesn't use these during creation/update.
    static func modelSupportsGenerationParameters(_ modelId: String) -> Bool {
        // Models that should NOT show temperature/top_p controls
        let unsupportedPrefixes = [
            "dall-e", "whisper", "tts", "text-embedding", "babbage", "davinci", "omni-moderation",
            "computer-use",
        ]
        // Allow o1, o3, o4 and their variants (reasoning models) to show controls
        for prefix in unsupportedPrefixes {
            if modelId.starts(with: prefix) {
                return false
            }
        }
        // All other models, including o1/o3/o4, support reasoning controls
        return true
    }

    /// Returns true if the model is a reasoning model (supports temperature/top_p).
    /// Reasoning models include GPT-4, GPT-4o, GPT-3.5-turbo, and OpenAI's omni models (o1, o3, o4).
    static func isReasoningModel(_ modelId: String) -> Bool {
        let reasoningPrefixes = [
            "gpt-4", "gpt-4o", "gpt-3.5-turbo", "o1", "o3", "o4"
        ]
        // Only show controls for models that start with a reasoning prefix
        return reasoningPrefixes.contains { modelId.starts(with: $0) }
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
