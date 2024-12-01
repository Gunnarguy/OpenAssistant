import Foundation
import Combine
import SwiftUI

@MainActor
class AssistantDetailViewModel: BaseViewModel {
    @Published var assistant: Assistant
    @Published var isLoading = false
    @Published var successMessage: SuccessMessage?

    init(assistant: Assistant) {
        self.assistant = assistant
        super.init()
    }

    // Update the assistant details
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
                self?.handleResult(result) { updatedAssistant in
                    self?.assistant = updatedAssistant
                    NotificationCenter.default.post(name: .assistantUpdated, object: updatedAssistant)
                }
            }
        }
    }

    // Delete the assistant
    func deleteAssistant() {
        performServiceAction { openAIService in
            openAIService.deleteAssistant(assistantId: assistant.id) { [weak self] result in
                self?.handleResult(result) {
                    NotificationCenter.default.post(name: .assistantDeleted, object: self?.assistant)
                    self?.handleError(IdentifiableError(message: "Assistant deleted successfully"))
                }
            }
        }
    }

    // Save Vector Store ID
    func saveVectorStoreId(_ vectorStoreId: String) {
        guard var toolResources = assistant.tool_resources else {
            assistant.tool_resources = ToolResources(fileSearch: FileSearchResources(vectorStoreIds: [vectorStoreId]))
            return
        }
        if toolResources.fileSearch == nil {
            toolResources.fileSearch = FileSearchResources(vectorStoreIds: [vectorStoreId])
        } else {
            toolResources.fileSearch?.vectorStoreIds?.append(vectorStoreId)
        }
        assistant.tool_resources = toolResources
        updateAssistant()
    }

    // Delete Vector Store ID
    func deleteVectorStoreId(_ vectorStoreId: String) {
        guard var toolResources = assistant.tool_resources,
              var vectorStoreIds = toolResources.fileSearch?.vectorStoreIds else {
            return
        }
        vectorStoreIds.removeAll { $0 == vectorStoreId }
        toolResources.fileSearch?.vectorStoreIds = vectorStoreIds
        assistant.tool_resources = toolResources
        updateAssistant()
    }

    func createAndAssociateVectorStore(name: String) {
        performServiceAction { openAIService in
            self.isLoading = true
            openAIService.createVectorStore(name: name) { [weak self] result in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    switch result {
                    case .success(let vectorStore):
                        if self?.assistant.tool_resources == nil {
                            self?.assistant.tool_resources = ToolResources(fileSearch: FileSearchResources(vectorStoreIds: []))
                        }
                        if self?.assistant.tool_resources?.fileSearch == nil {
                            self?.assistant.tool_resources?.fileSearch = FileSearchResources(vectorStoreIds: [])
                        }
                        self?.assistant.tool_resources?.fileSearch?.vectorStoreIds?.append(vectorStore.id)
                        self?.updateAssistant()
                        self?.successMessage = SuccessMessage(message: "Vector Store created and associated successfully.")
                    case .failure(let error):
                        self?.handleError(IdentifiableError(message: "Failed to create vector store: \(error.localizedDescription)"))
                    }
                }
            }
        }
    }

    // Perform a service action with OpenAI
    private func performServiceAction(action: (OpenAIService) -> Void) {
        guard let openAIService = openAIService else {
            handleError(IdentifiableError(message: "OpenAIService is not initialized"))
            return
        }
        action(openAIService)
    }

    // Handle result and errors
    private func handleResult<T>(_ result: Result<T, OpenAIServiceError>, successHandler: @escaping (T) -> Void) {
        DispatchQueue.main.async {
            switch result {
            case .success(let value):
                successHandler(value)
            case .failure(let error):
                self.handleError(IdentifiableError(message: "Operation failed: \(error.localizedDescription)"))
            }
        }
    }

    struct SuccessMessage: Identifiable {
        let id = UUID()
        let message: String
    }
}
