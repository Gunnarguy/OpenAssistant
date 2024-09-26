import Foundation
import Combine
import SwiftUI

@MainActor
class AssistantDetailViewModel: ObservableObject {
    @Published var assistant: Assistant
    @Published var errorMessage: String?
    private var openAIService: OpenAIService?
    private var cancellables = Set<AnyCancellable>()
    private let errorHandler = ErrorHandler()
    
    // Fetch API Key from UserDefaults
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "OpenAI_API_Key") ?? ""
    }
    
    // Initialize the ViewModel with an Assistant
    init(assistant: Assistant) {
        self.assistant = assistant
        initializeOpenAIService()
    }
    
    // Initialize OpenAI service using the API key
    private func initializeOpenAIService() {
        openAIService = OpenAIServiceInitializer.initialize(apiKey: apiKey)
        if openAIService == nil {
            errorHandler.handleError("API key is missing")
        }
    }

        func createVectorStoreWithFileIds(name: String, fileIds: [String], completion: @escaping (Result<VectorStore, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/vector_stores") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let body: [String: Any] = [
            "name": name,
            "file_ids": fileIds
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            do {
                let response = try JSONDecoder().decode(VectorStore.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Function to update an assistant
    func updateAssistant() {
        performServiceAction { openAIService in
            openAIService.updateAssistant(
                assistantId: assistant.id,
                model: assistant.model,
                name: assistant.name,
                description: assistant.description,
                instructions: assistant.instructions,
                tools: assistant.tools.map { $0.toDictionary() },
                toolResources: assistant.tool_resources?.toDictionary(),
                metadata: assistant.metadata,
                temperature: assistant.temperature,
                topP: assistant.top_p
            ) { [weak self] result in
                self?.handleResult(result, successHandler: { updatedAssistant in
                    self?.assistant = updatedAssistant
                    NotificationCenter.default.post(name: .assistantUpdated, object: updatedAssistant)
                })
            }
        }
    }
    
    // Function to delete an assistant
    func deleteAssistant() {
        performServiceAction { openAIService in
            openAIService.deleteAssistant(assistantId: assistant.id) { [weak self] result in
                self?.handleResult(result, successHandler: {
                    NotificationCenter.default.post(name: .assistantDeleted, object: self?.assistant)
                    self?.errorHandler.handleError("Assistant deleted successfully")
                })
            }
        }
    }
    
    // Perform a service action with OpenAI
    private func performServiceAction(action: (OpenAIService) -> Void) {
        guard let openAIService = openAIService else {
            errorHandler.handleError("OpenAIService is not initialized")
            return
        }
        action(openAIService)
    }
    
    // Generic result handler for success and error management
    private func handleResult<T>(_ result: Result<T, OpenAIServiceError>, successHandler: @escaping (T) -> Void) {
        DispatchQueue.main.async {
            switch result {
            case .success(let value):
                successHandler(value)
            case .failure(let error):
                self.errorHandler.handleError("Operation failed: \(error.localizedDescription)")
            }
        }
    }
}
