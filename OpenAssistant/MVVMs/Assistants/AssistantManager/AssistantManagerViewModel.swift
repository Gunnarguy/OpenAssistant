import Combine
import Foundation
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

    // Fetches available models from OpenAI API
    func fetchAvailableModels() {
        performServiceAction { openAIService in
            openAIService.fetchAvailableModels { [weak self] result in
                self?.handleModelsResult(result)
            }
        }
    }

    private func handleModelsResult(_ result: Result<[String], Error>) {
        DispatchQueue.main.async {
            switch result {
            case .success(let models):
                // Do NOT filter to only reasoning models. Show all available models.
                self.availableModels = models.sorted()
                print("Available models: \(models)")
            case .failure(let error):
                self.handleError(
                    IdentifiableError(message: "Fetch models failed: \(error.localizedDescription)")
                )
                print("Error fetching models: \(error.localizedDescription)")
            }
        }
    }

    // Fetches the vector stores from the API
    func fetchVectorStores() {
        performServiceAction { openAIService in
            openAIService.fetchVectorStores()
                .receive(on: DispatchQueue.main)  // Ensure updates happen on the main thread
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.handleError(
                                IdentifiableError(
                                    message:
                                        "Fetch vector stores failed: \(error.localizedDescription)")
                            )
                        }
                    },
                    receiveValue: { [weak self] vectorStores in
                        self?.vectorStores = vectorStores
                    }
                )
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
        temperature: Double,  // Generation temperature
        topP: Double,  // Generation top-p
        reasoningEffort: String?,  // Reasoning effort for O-series models
        responseFormat: ResponseFormat?
    ) {
        // Ensure service is available before proceeding
        performServiceAction { openAIService in
            // Call the underlying service method to create the assistant
            openAIService.createAssistant(
                model: model,
                name: name,
                description: description,
                instructions: instructions,
                // Convert Tool and ToolResources structs to dictionaries for the API
                tools: tools.map { $0.toDictionary() },
                toolResources: toolResources?.toDictionary(),
                metadata: metadata,
                temperature: temperature,  // Pass temperature
                topP: topP,  // Pass topP
                reasoningEffort: reasoningEffort,  // Pass reasoning effort
                responseFormat: responseFormat
            ) { [weak self] (result: Result<Assistant, OpenAIServiceError>) in
                // Handle the result on the main thread for UI updates
                DispatchQueue.main.async {
                    self?.handleResult(result) { assistant in
                        // On success, add the new assistant to the local list
                        self?.assistants.append(assistant)
                        // Notify other parts of the app
                        NotificationCenter.default.post(name: .assistantCreated, object: assistant)
                    }
                }
            }
        }
    }

    // Updates an existing assistant
    func updateAssistant(assistant: Assistant, completion: @escaping (Result<Void, Error>) -> Void)
    {
        // Ensure service is available before proceeding
        performServiceAction { openAIService in
            // Call the service method to update the assistant
            openAIService.updateAssistant(
                assistantId: assistant.id,
                // model: assistant.model, // REMOVED passing model again
                name: assistant.name,
                description: assistant.description,
                instructions: assistant.instructions,
                // Convert Tool and ToolResources structs to dictionaries for the API
                tools: assistant.tools.map { $0.toDictionary() },
                toolResources: assistant.tool_resources?.toDictionary(),
                metadata: assistant.metadata,
                temperature: assistant.temperature,  // Pass temperature
                topP: assistant.top_p,  // Pass topP
                reasoningEffort: assistant.reasoning_effort,  // Pass reasoning effort
                responseFormat: assistant.response_format,  // Pass response format if needed
                // Pass the completion handler to the service call
                completion: { [weak self] (result: Result<Assistant, OpenAIServiceError>) in
                    // Handle the result on the main thread for UI updates
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let updatedAssistant):
                            // Update the local assistants array with the modified assistant
                            if let index = self?.assistants.firstIndex(where: {
                                $0.id == assistant.id
                            }) {
                                self?.assistants[index] = updatedAssistant
                            }
                            // Notify other parts of the app about the update
                            NotificationCenter.default.post(
                                name: .assistantUpdated, object: updatedAssistant)
                            // Call the original completion handler indicating success
                            completion(.success(()))
                        case .failure(let error):
                            // Handle the error (e.g., show an alert to the user)
                            self?.handleError(
                                IdentifiableError(
                                    message:
                                        "Update assistant failed: \(error.localizedDescription)"))
                            // Call the original completion handler with the error
                            completion(.failure(error))
                        }
                    }
                }
            )
        }
    }

    private func makeRequest(endpoint: String, httpMethod: String, body: [String: Any])
        -> URLRequest?
    {
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
    func handleResponse(
        data: Data?, response: URLResponse?, error: Error?,
        completion: (Result<Assistant, OpenAIServiceError>) -> Void
    ) {
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
            completion(.failure(.decodingError(data, error)))  // Add data parameter
        }
    }

    // Deletes an assistant
    func deleteAssistant(assistant: Assistant) {
        performServiceAction { openAIService in
            openAIService.deleteAssistant(assistantId: assistant.id) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleResult(result) {
                        if let index = self?.assistants.firstIndex(where: { $0.id == assistant.id })
                        {
                            self?.assistants.remove(at: index)
                            NotificationCenter.default.post(
                                name: .assistantDeleted, object: assistant)
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
        let notifications: [Notification.Name] = [
            .assistantCreated, .assistantUpdated, .assistantDeleted,
        ]

        notifications.forEach { notification in
            notificationCenter.publisher(for: notification)
                .receive(on: DispatchQueue.main)  // Ensure updates happen on the main thread
                .sink { [weak self] _ in self?.fetchAssistants() }
                .store(in: &cancellables)
        }
    }
}
