import Combine
import Foundation
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
        // Log the model being used just before the update API call
        let originalModel = assistant.model  // Store original model for comparison
        print("Attempting to update assistant ID: \(assistant.id) with model: \(originalModel)")

        // Check if it's a restricted model before proceeding
        guard !isRestrictedModelForUpdate(assistant.model) else {
            print(
                "Update blocked: Updates for this model (\(assistant.model)) are disabled due to API limitations."
            )
            return
        }

        performServiceAction { openAIService in
            openAIService.updateAssistant(
                assistantId: assistant.id,
                // model parameter is correctly omitted here
                name: assistant.name,
                description: assistant.description,
                instructions: assistant.instructions,
                tools: assistant.tools.map { $0.toDictionary() },
                toolResources: assistant.tool_resources?.toDictionary(),
                metadata: assistant.metadata,
                responseFormat: assistant.response_format
            ) { [weak self] (result: Result<Assistant, OpenAIServiceError>) in
                guard let self = self else { return }

                // Handle the result directly
                DispatchQueue.main.async {
                    switch result {
                    case .success(let updatedAssistant):
                        print(
                            "Update successful. Assistant ID: \(updatedAssistant.id), Model: \(updatedAssistant.model)"
                        )
                        // Update local state with the response from the POST
                        self.assistant = updatedAssistant
                        NotificationCenter.default.post(
                            name: .assistantUpdated, object: updatedAssistant)
                        // Optionally show success message
                        self.successMessage = SuccessMessage(
                            message: "Assistant updated successfully.")

                    case .failure(let error):
                        // Handle the error from the POST request
                        let errorMessage = "Update assistant failed: \(error.localizedDescription)"
                        print("ERROR: \(errorMessage)")
                        self.handleError(IdentifiableError(message: errorMessage))
                    }
                }
            }
        }
    }

    // Delete the assistant
    func deleteAssistant() {
        performServiceAction { openAIService in
            openAIService.deleteAssistant(assistantId: assistant.id) {
                [weak self] (result: Result<Void, OpenAIServiceError>) in
                self?.handleResult(result) { (_: Void) in
                    NotificationCenter.default.post(
                        name: .assistantDeleted, object: self?.assistant)
                    self?.handleError(IdentifiableError(message: "Assistant deleted successfully"))
                }
            }
        }
    }

    // Save Vector Store ID
    func saveVectorStoreId(_ vectorStoreId: String) {
        guard var toolResources = assistant.tool_resources else {
            assistant.tool_resources = ToolResources(
                fileSearch: FileSearchResources(vectorStoreIds: [vectorStoreId]))
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
            var vectorStoreIds = toolResources.fileSearch?.vectorStoreIds
        else {
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
                            self?.assistant.tool_resources = ToolResources(
                                fileSearch: FileSearchResources(vectorStoreIds: []))
                        }
                        if self?.assistant.tool_resources?.fileSearch == nil {
                            self?.assistant.tool_resources?.fileSearch = FileSearchResources(
                                vectorStoreIds: [])
                        }
                        self?.assistant.tool_resources?.fileSearch?.vectorStoreIds?.append(
                            vectorStore.id)
                        self?.updateAssistant()
                        self?.successMessage = SuccessMessage(
                            message: "Vector Store created and associated successfully.")
                    case .failure(let error):
                        self?.handleError(
                            IdentifiableError(
                                message:
                                    "Failed to create vector store: \(error.localizedDescription)"))
                    }
                }
            }
        }
    }

    // Helper function to check for models restricted from updates
    private func isRestrictedModelForUpdate(_ modelId: String) -> Bool {
        let lowercasedModel = modelId.lowercased()
        return lowercasedModel.starts(with: "o1") || lowercasedModel.starts(with: "o3")
            || lowercasedModel.starts(with: "o4") || lowercasedModel == "gpt-4o-mini"  // Add gpt-4o-mini
    }

    struct SuccessMessage: Identifiable {
        let id = UUID()
        let message: String
    }
}
