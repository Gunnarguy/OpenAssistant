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
        // Use the hardcoded list provided by the user for now.
        // In a real scenario, you might still fetch from the API and then filter/sort.
        let allModels = [
            "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano", "gpt-4o", "gpt-4o-mini",
            "o3-mini-2025-01-31", "o3-mini", "o1-2024-12-17", "o1",
            "gpt-4o-mini-2024-07-18", "gpt-4o-2024-11-20", "gpt-4o-2024-08-06",
            "gpt-4o-2024-05-13", "gpt-4.5-preview-2025-02-27", "gpt-4.5-preview",
            "gpt-4.1-nano-2025-04-14", "gpt-4.1-mini-2025-04-14",
            "gpt-4.1-2025-04-14", "gpt-4-turbo-preview", "gpt-4-turbo-2024-04-09",
            "gpt-4-turbo", "gpt-4-1106-preview", "gpt-4-0613", "gpt-4-0125-preview",
            "gpt-4", "gpt-3.5-turbo-16k", "gpt-3.5-turbo-1106", "gpt-3.5-turbo-0125",
            "gpt-3.5-turbo",
        ].sorted()  // Sort the list alphabetically

        self.availableModels = allModels
        print("Available models set to predefined list: \(allModels)")

        // Keep the API call commented out or remove if not needed
        /*
        performServiceAction { openAIService in
            openAIService.fetchAvailableModels { [weak self] result in
                self?.handleModelsResult(result)
            }
        }
        */
    }

    // Keep handleModelsResult in case you switch back to API fetching later
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
                    switch result {
                    case .success:
                        // Remove the assistant from the local array
                        self?.assistants.removeAll { $0.id == assistant.id }

                        // Post notification that an assistant was deleted
                        NotificationCenter.default.post(name: .assistantDeleted, object: nil)

                        print("Assistant '\(assistant.name)' deleted successfully")
                    case .failure(let error):
                        // Handle the error
                        self?.handleError(
                            IdentifiableError(
                                message: "Delete assistant failed: \(error.localizedDescription)"
                            )
                        )
                        print("Error deleting assistant: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Notification Observers

    // Handles the notification when an assistant is updated
    @objc private func assistantDidUpdate() {
        fetchAssistants()
    }

    override func setupNotificationObservers() {
        super.setupNotificationObservers()
        let notificationCenter = NotificationCenter.default

        // Listen for standard assistant notifications using publisher pattern
        let refetchNotifications: [Notification.Name] = [
            .assistantCreated, .assistantDeleted,
        ]

        refetchNotifications.forEach { notificationName in
            notificationCenter.publisher(for: notificationName)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.fetchAssistants() }
                .store(in: &cancellables)
        }

        // Handle assistant updates more efficiently
        notificationCenter.publisher(for: .assistantUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self, let updatedAssistant = notification.object as? Assistant
                else {
                    self?.fetchAssistants()  // Fallback to refetch
                    return
                }

                if let index = self.assistants.firstIndex(where: { $0.id == updatedAssistant.id }) {
                    self.assistants[index] = updatedAssistant
                } else {
                    self.fetchAssistants()  // If not found, refetch
                }
            }
            .store(in: &cancellables)

        // Also add observer for the custom didUpdateAssistant notification
        notificationCenter.addObserver(
            self,
            selector: #selector(assistantDidUpdate),
            name: .didUpdateAssistant,
            object: nil
        )
    }
}
