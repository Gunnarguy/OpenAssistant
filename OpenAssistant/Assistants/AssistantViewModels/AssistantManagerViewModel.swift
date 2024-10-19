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
                self?.handleResult(result) { assistants in
                    self?.assistants = assistants
                }
                self?.isLoading = false
            }
        }
    }

    // Fetches the available models from the API
    func fetchAvailableModels() {
        performServiceAction { openAIService in
            openAIService.fetchAvailableModels { [weak self] result in
                self?.handleModelsResult(result)
            }
        }
    }

    // Fetches the vector stores from the API
    func fetchVectorStores() {
        performServiceAction { openAIService in
            openAIService.fetchVectorStores()
                .receive(on: DispatchQueue.main)
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
    func createAssistant(model: String,
                         name: String,
                         description: String?,
                         instructions: String?,
                         tools: [Tool],
                         toolResources: ToolResources?,
                         metadata: [String: String]?,
                         temperature: Double,
                         topP: Double,
                         responseFormat: ResponseFormat?) {
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
                self?.handleResult(result) { assistant in
                    self?.assistants.append(assistant)
                    NotificationCenter.default.post(name: .assistantCreated, object: assistant)
                }
            }
        }
    }

    // Updates an existing assistant
    func updateAssistant(assistant: Assistant) {
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
                topP: assistant.top_p,
                responseFormat: assistant.response_format
            ) { [weak self] result in
                self?.handleResult(result) { updatedAssistant in
                    if let index = self?.assistants.firstIndex(where: { $0.id == updatedAssistant.id }) {
                        self?.assistants[index] = updatedAssistant
                        NotificationCenter.default.post(name: .assistantUpdated, object: updatedAssistant)
                    }
                }
            }
        }
    }

    // Deletes an assistant
    func deleteAssistant(assistant: Assistant) {
        performServiceAction { openAIService in
            openAIService.deleteAssistant(assistantId: assistant.id) { [weak self] result in
                self?.handleResult(result) {
                    if let index = self?.assistants.firstIndex(where: { $0.id == assistant.id }) {
                        self?.assistants.remove(at: index)
                        NotificationCenter.default.post(name: .assistantDeleted, object: assistant)
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    // Handles the result of fetching models
    private func handleModelsResult(_ result: Result<[String], Error>) {
        switch result {
        case .success(let models):
            // Define a set of prefixes for models you want to include
            let modelPrefixes = ["gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"]
            let excludedKeywords = ["audio", "realtime"]

            DispatchQueue.main.async {
                self.availableModels = models.filter { model in
                    modelPrefixes.contains { prefix in model.hasPrefix(prefix) } &&
                    !excludedKeywords.contains { keyword in model.contains(keyword) }
                }
            }
        case .failure(let error):
            DispatchQueue.main.async {
                self.handleError(IdentifiableError(message: "Fetch models failed: \(error.localizedDescription)"))
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
                .sink { [weak self] _ in self?.fetchAssistants() }
                .store(in: &cancellables)
        }
    }
}
