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

    func fetchAvailableModels() {
        performServiceAction { openAIService in
            openAIService.fetchAvailableModels { [weak self] result in
                self?.handleModelsResult(result)
            }
        }
    }

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

    private func handleModelsResult(_ result: Result<[String], Error>) {
        switch result {
        case .success(let models):
            self.availableModels = models.filter { $0.contains("gpt-3.5") || $0.contains("gpt-4") }
        case .failure(let error):
            self.handleError(IdentifiableError(message: "Fetch models failed: \(error.localizedDescription)"))
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
