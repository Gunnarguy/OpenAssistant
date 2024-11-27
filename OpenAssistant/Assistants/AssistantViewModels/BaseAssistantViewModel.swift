import Foundation
import Combine
import SwiftUI

@MainActor
class BaseAssistantViewModel: ObservableObject {
    @Published var errorMessage: IdentifiableError?
    var openAIService: OpenAIService?
    var cancellables = Set<AnyCancellable>()

    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""

    init() {
        initializeOpenAIService()
        setupNotificationObservers()
    }

    func initializeOpenAIService() {
        if apiKey.isEmpty {
            return
        }
        openAIService = OpenAIServiceInitializer.initialize(apiKey: apiKey)
    }

    func performServiceAction(action: (OpenAIService) -> Void) {
        guard let openAIService = openAIService else {
            handleError(IdentifiableError(message: "OpenAIService is not initialized"))
            return
        }
        action(openAIService)
    }

    func handleResult<T>(_ result: Result<T, OpenAIServiceError>, successHandler: @escaping (T) -> Void) {
        switch result {
        case .success(let value):
            successHandler(value)
        case .failure(let error):
            handleError(IdentifiableError(message: "Operation failed: \(error.localizedDescription)"))
        }
    }

    func handleError(_ error: IdentifiableError) {
        errorMessage = error
    }

    func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .settingsUpdated)
            .sink { [weak self] _ in
                self?.updateApiKey()
            }
            .store(in: &cancellables)
    }

    func updateApiKey() {
        openAIService = OpenAIServiceInitializer.reinitialize(apiKey: apiKey)
    }
}
