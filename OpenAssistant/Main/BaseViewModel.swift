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
    }

    // MARK: - Service Initialization
    func initializeOpenAIService() {
        guard !apiKey.isEmpty else {
            handleError(IdentifiableError(message: "API key is missing"))
            return
        }
        openAIService = OpenAIService(apiKey: apiKey)
    }

    // MARK: - Error Handling
    func handleError(_ error: IdentifiableError) {
        errorMessage = error
    }
}


