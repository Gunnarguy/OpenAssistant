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
<<<<<<< HEAD
                self.availableModels = models
                print("Models fetched successfully: \(models)")
=======
                // Only include models that support reasoning (no embeddings, DALL-E, etc.)
                let filteredModels = models.filter { modelId in
                    // Case-insensitive filter against reasoning models
                    BaseViewModel.isReasoningModel(modelId.lowercased())
                }
                self.availableModels = filteredModels.sorted()
                print("Available reasoning models: \(filteredModels)")
>>>>>>> f4401e5 (Add release configuration, fix App Store rejection issues, and update documentation)
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
                responseFormat: responseFormat
            ) { [weak self] (result: Result<Assistant, OpenAIServiceError>) in
                DispatchQueue.main.async {
                    self?.handleResult(result) { assistant in
                        self?.assistants.append(assistant)
                        NotificationCenter.default.post(name: .assistantCreated, object: assistant)
                    }
                }
            }
        }
    }

    // Updates an existing assistant
    func updateAssistant(assistant: Assistant, completion: @escaping (Result<Void, Error>) -> Void)
    {
        performServiceAction { openAIService in
            // Call the service method to update the assistant
            openAIService.updateAssistant(
                assistantId: assistant.id,
                model: assistant.model,
                name: assistant.name,
                description: assistant.description,
                instructions: assistant.instructions,
                tools: assistant.tools.map { $0.toDictionary() },
                toolResources: assistant.tool_resources?.toDictionary(),
                metadata: assistant.metadata,
<<<<<<< HEAD
                // Removed temperature and topP as they might not be direct parameters for update
                // Pass the completion handler correctly
=======
                temperature: assistant.temperature,  // persist updated temperature
                topP: assistant.top_p,              // persist updated top_p
                responseFormat: assistant.response_format,
>>>>>>> f4401e5 (Add release configuration, fix App Store rejection issues, and update documentation)
                completion: { [weak self] (result: Result<Assistant, OpenAIServiceError>) in  // Explicitly type result
                    // Ensure UI updates are on the main thread
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let updatedAssistant):
                            // Update the local assistants array
                            self?.assistants =
                                self?.assistants.map {
                                    $0.id == assistant.id ? updatedAssistant : $0
                                } ?? []
                            // Notify other parts of the app about the update
                            NotificationCenter.default.post(
                                name: .assistantUpdated, object: updatedAssistant)
                            // Call the original completion handler passed to updateAssistant
                            completion(.success(()))
                        case .failure(let error):
                            // Handle the error appropriately (e.g., show an alert)
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
