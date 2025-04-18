import Foundation
import Combine
import SwiftUI

@MainActor
class AssistantManagerViewModel: BaseAssistantViewModel {
    @Published var assistants: [Assistant] = []
    @Published var availableModels: [String] = []
    @Published var vectorStores: [VectorStore] = []
    @Published var isLoading = false
    

    override init() {
        super.init()
        fetchData()
        setupNotificationObservers()
    }

    // MARK: - Fetch Data

    private func fetchData() {
        fetchAssistants()
        fetchAvailableModels()
        fetchVectorStores()
    }

    // Fetches the list of assistants from the API
    func fetchAssistants() {
        performServiceAction { openAIService in
            self.isLoading = true
            openAIService.fetchAssistants { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleResult(result) { assistants in
                        self?.assistants = assistants
                    }
                    self?.isLoading = false
                }
            }
        }
    }

    // Fetches available models asynchronously
    func fetchAvailableModels() {
        DispatchQueue.global(qos: .background).async {
            // Simulate fetching available models
            let models = ["gpt-4o-mini", "gpt-4o"]
            DispatchQueue.main.async {
                self.availableModels = models
            }
        }
    }

    private func handleModelsResult(_ result: Result<[String], Error>) {
        DispatchQueue.main.async {
            switch result {
            case .success(let models):
                self.availableModels = models
                print("Models fetched successfully: \(models)")
            case .failure(let error):
                self.handleError(IdentifiableError(message: "Fetch models failed: \(error.localizedDescription)"))
                print("Error fetching models: \(error.localizedDescription)")
            }
        }
    }

    // Fetches the vector stores from the API
    func fetchVectorStores() {
        performServiceAction { openAIService in
            openAIService.fetchVectorStores()
                .receive(on: DispatchQueue.main) // Ensure updates happen on the main thread
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(IdentifiableError(message: "Fetch vector stores failed: \(error.localizedDescription)"))
                    }
                }, receiveValue: { [weak self] vectorStores in
                    self?.vectorStores = vectorStores
                })
                .store(in: &self.cancellables)
        }
    }

    // MARK: - Assistant Management

    // Creates a new assistant using the specified parameters
    func createAssistant(
        model: String,
        name: String,
        description: String?,
        instructions: String?,
        tools: [Tool],
        toolResources: ToolResources?,
        metadata: [String: String]?,
        temperature: Double,
        topP: Double,
        responseFormat: ResponseFormat?
    ) {
        performServiceAction { openAIService in
            openAIService.createAssistant(
                model: model,
                name: name,
                description: description,
                instructions: instructions,
                tools: tools.map { $0.toDictionary() },
                toolResources: toolResources?.toDictionary(),
                metadata: metadata,
                temperature: temperature,
                topP: topP,
                responseFormat: responseFormat
            ) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleResult(result) { assistant in
                        self?.assistants.append(assistant)
                        NotificationCenter.default.post(name: .assistantCreated, object: assistant)
                    }
                }
            }
        }
    }

    func updateAssistant(assistant: Assistant, completion: @escaping (Result<Void, Error>) -> Void) {
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
                DispatchQueue.main.async {
                    switch result {
                    case .success(let updatedAssistant):
                        self?.assistants = self?.assistants.map {
                            $0.id == assistant.id ? updatedAssistant : $0
                        } ?? []
                        NotificationCenter.default.post(name: .assistantUpdated, object: updatedAssistant)
                        completion(.success(()))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    private func makeRequest(endpoint: String, httpMethod: String, body: [String: Any]) -> URLRequest? {
        guard let url = URL(string: "https://api.openai.com/v1/\(endpoint)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        
        // Use the OpenAIService instance instead of direct apiKey access
        guard let openAIService = openAIService else { return nil }
        
        request.setValue("Bearer \(openAIService.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            return nil
        }

        return request
    }

    // And fix the decodingError call by providing both required parameters:
    func handleResponse(data: Data?, response: URLResponse?, error: Error?, completion: (Result<Assistant, OpenAIServiceError>) -> Void) {
        if let error = error {
            completion(.failure(.networkError(error)))
            return
        }
        
        guard let data = data else {
            completion(.failure(.noData))
            return
        }
        
        do {
            let assistant = try JSONDecoder().decode(Assistant.self, from: data)
            completion(.success(assistant))
        } catch {
            completion(.failure(.decodingError(data, error))) // Add data parameter
        }
    }

    // Deletes an assistant
    func deleteAssistant(assistant: Assistant) {
        performServiceAction { openAIService in
            openAIService.deleteAssistant(assistantId: assistant.id) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleResult(result) {
                        if let index = self?.assistants.firstIndex(where: { $0.id == assistant.id }) {
                            self?.assistants.remove(at: index)
                            NotificationCenter.default.post(name: .assistantDeleted, object: assistant)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Notification Observers

    override func setupNotificationObservers() {
        super.setupNotificationObservers()
        let notificationCenter = NotificationCenter.default
        let notifications: [Notification.Name] = [.assistantCreated, .assistantUpdated, .assistantDeleted]

        notifications.forEach { notification in
            notificationCenter.publisher(for: notification)
                .receive(on: DispatchQueue.main) // Ensure updates happen on the main thread
                .sink { [weak self] _ in self?.fetchAssistants() }
                .store(in: &cancellables)
        }
    }
}
