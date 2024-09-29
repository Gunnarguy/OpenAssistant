import Foundation
import Combine

@MainActor
class BaseAssistantViewModel: ObservableObject {
    @Published var errorMessage: String?
    var openAIService: OpenAIService?
    var cancellables = Set<AnyCancellable>()

    // Fetch API Key from UserDefaults or AppStorage
    var apiKey: String {
        UserDefaults.standard.string(forKey: "OpenAI_API_Key") ?? ""
    }

    init() {
        initializeOpenAIService()
    }

    /// Initializes the OpenAIService with the API key.
    func initializeOpenAIService() {
        guard !apiKey.isEmpty else {
            handleError("API key is missing")
            return
        }
        openAIService = OpenAIServiceInitializer.initialize(apiKey: apiKey)
    }

    /// Performs an action with the OpenAIService if it is initialized.
    /// - Parameter action: The action to perform.
    func performServiceAction(action: (OpenAIService) -> Void) {
        guard let openAIService = openAIService else {
            handleError("OpenAIService is not initialized")
            return
        }
        action(openAIService)
    }

    /// Handles the result of a service action.
    /// - Parameters:
    ///   - result: The result of the service action.
    ///   - successHandler: The handler to call on success.
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
    
    /// Handles errors by setting the errorMessage property.
    /// - Parameter message: The error message to display.
    func handleError(_ message: String) {
        errorMessage = message
    }
}
