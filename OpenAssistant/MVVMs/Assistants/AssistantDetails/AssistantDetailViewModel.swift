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

    // MARK: - Update Assistant

    // Updates the assistant's details via the API service.
    func updateAssistant() {
        // Determine the model being saved
        let modelToSave = assistant.model
        print("Attempting to update assistant ID: \(assistant.id) with model: \(modelToSave)")

        // Determine which generation parameters to send based on the model
        var tempToSend: Double? = nil
        var topPToSend: Double? = nil
        var reasoningToSend: String? = nil

        // Check model type using the static helper from the superclass
        if BaseViewModel.supportsTempTopPAtAssistantLevel(modelToSave) {
            tempToSend = assistant.temperature
            topPToSend = assistant.top_p
            reasoningToSend = nil  // Explicitly set reasoning to nil for non-O models
            print(" -> Sending temp: \(tempToSend ?? 0.0), top_p: \(topPToSend ?? 0.0)")
        } else if BaseViewModel.isReasoningModel(modelToSave) {
            tempToSend = nil  // Explicitly set temp to nil for O models
            topPToSend = nil  // Explicitly set topP to nil for O models
            reasoningToSend = assistant.reasoning_effort  // Use value from state
            print(" -> Sending reasoning_effort: \(reasoningToSend ?? "default")")
        } else {
            // Handle cases where model supports neither (future-proofing)
            tempToSend = nil
            topPToSend = nil
            reasoningToSend = nil
            print(
                " -> Model type does not support temp/topP or reasoning effort at assistant level.")
        }

        // Log the parameters being sent
        print(
            "Parameters to send - Temp: \(tempToSend?.description ?? "nil"), TopP: \(topPToSend?.description ?? "nil"), Reasoning: \(reasoningToSend ?? "nil")"
        )

        // Perform the API call
        performServiceAction { openAIService in
            // Ensure isLoading is managed if needed
            // self.isLoading = true
            openAIService.updateAssistant(
                assistantId: assistant.id,
                // Pass the potentially updated model. The API might restrict changing between families (e.g., GPT-4 to O-series).
                model: modelToSave,
                name: assistant.name,
                description: assistant.description,
                instructions: assistant.instructions,
                tools: assistant.tools.map { $0.toDictionary() },
                toolResources: assistant.tool_resources?.toDictionary(),
                metadata: assistant.metadata,
                temperature: tempToSend,  // Pass determined temperature (or nil)
                topP: topPToSend,  // Pass determined topP (or nil)
                reasoningEffort: reasoningToSend,  // Pass determined reasoning effort (or nil)
                responseFormat: assistant.response_format
            ) { [weak self] (result: Result<Assistant, OpenAIServiceError>) in
                guard let self = self else { return }
                // self.isLoading = false // Manage loading state

                // Handle the result directly
                DispatchQueue.main.async {
                    switch result {
                    case .success(let updatedAssistant):
                        // ... existing success handling ...
                        print(
                            "Update successful. Assistant ID: \(updatedAssistant.id), Model: \(updatedAssistant.model), Temp: \(updatedAssistant.temperature), TopP: \(updatedAssistant.top_p), Reasoning: \(updatedAssistant.reasoning_effort ?? "nil")"
                        )
                        self.assistant = updatedAssistant
                        NotificationCenter.default.post(
                            name: .assistantUpdated, object: updatedAssistant)
                        self.successMessage = SuccessMessage(
                            message: "Assistant updated successfully.")

                    case .failure(let error):
                        // ... existing error handling ...
                        let errorMessage = "Update assistant failed: \(error.localizedDescription)"
                        print("ERROR: \(errorMessage)")
                        self.fetchAssistantDetails()  // Revert local state
                        self.handleError(IdentifiableError(message: errorMessage))
                    }
                }
            }
        }
    }

    // MARK: - Fetch Assistant Details

    // Fetches the latest assistant details, typically used to revert state after a failed update.
    private func fetchAssistantDetails() {
        performServiceAction { openAIService in
            openAIService.fetchAssistantDetails(assistantId: assistant.id) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let fetchedAssistant):
                        print("Successfully fetched latest assistant details after failed update.")
                        self.assistant = fetchedAssistant  // Revert local state to fetched state
                    case .failure(let fetchError):
                        let fetchErrorMessage =
                            "Failed to fetch assistant details after update failure: \(fetchError.localizedDescription)"
                        print("ERROR: \(fetchErrorMessage)")
                        // Optionally, show another error specific to the fetch failure
                        self.handleError(IdentifiableError(message: fetchErrorMessage))
                    }
                }
            }
        }
    }

    // MARK: - Delete Assistant

    // Deletes the current assistant.
    func deleteAssistant() {
        performServiceAction { openAIService in
            openAIService.deleteAssistant(assistantId: assistant.id) {
                [weak self] (result: Result<Void, OpenAIServiceError>) in
                self?.handleResult(result) { (_: Void) in
                    NotificationCenter.default.post(
                        name: .assistantDeleted, object: self?.assistant)
                    // Consider dismissing the view or navigating away after successful deletion
                    // self?.handleError(IdentifiableError(message: "Assistant deleted successfully")) // Maybe show a less alarming message
                }
            }
        }
    }

    // MARK: - Vector Store Management

    // Saves a vector store ID to the assistant's tool resources and updates the assistant.
    func saveVectorStoreId(_ vectorStoreId: String) {
        // Ensure tool_resources exists
        if assistant.tool_resources == nil {
            assistant.tool_resources = ToolResources(fileSearch: nil, codeInterpreter: nil)
        }
        // Ensure fileSearch exists within tool_resources
        if assistant.tool_resources?.fileSearch == nil {
            assistant.tool_resources?.fileSearch = FileSearchResources(vectorStoreIds: [])
        }
        // Ensure vectorStoreIds exists and append the new ID if not already present
        if assistant.tool_resources?.fileSearch?.vectorStoreIds?.contains(vectorStoreId) == false {
            assistant.tool_resources?.fileSearch?.vectorStoreIds?.append(vectorStoreId)
        } else if assistant.tool_resources?.fileSearch?.vectorStoreIds == nil {
            assistant.tool_resources?.fileSearch?.vectorStoreIds = [vectorStoreId]
        }

        // Persist the change by calling updateAssistant
        updateAssistant()
    }

    // Deletes a vector store ID from the assistant's tool resources and updates the assistant.
    func deleteVectorStoreId(_ vectorStoreId: String) {
        // Check if tool resources and file search resources exist
        guard assistant.tool_resources?.fileSearch?.vectorStoreIds != nil else {
            print("No vector store IDs to delete from.")
            return
        }
        // Remove the specified ID
        assistant.tool_resources?.fileSearch?.vectorStoreIds?.removeAll { $0 == vectorStoreId }

        // Persist the change by calling updateAssistant
        updateAssistant()
    }

    // Creates a new vector store and associates it with the assistant.
    func createAndAssociateVectorStore(name: String) {
        performServiceAction { openAIService in
            self.isLoading = true
            openAIService.createVectorStore(name: name) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }  // Ensure self is available
                    self.isLoading = false
                    switch result {
                    case .success(let vectorStore):
                        // Ensure tool_resources and fileSearch exist before appending
                        if self.assistant.tool_resources == nil {
                            self.assistant.tool_resources = ToolResources(
                                fileSearch: nil, codeInterpreter: nil)
                        }
                        if self.assistant.tool_resources?.fileSearch == nil {
                            self.assistant.tool_resources?.fileSearch = FileSearchResources(
                                vectorStoreIds: [])
                        }
                        if self.assistant.tool_resources?.fileSearch?.vectorStoreIds == nil {
                            self.assistant.tool_resources?.fileSearch?.vectorStoreIds = []
                        }

                        // Append the new vector store ID
                        self.assistant.tool_resources?.fileSearch?.vectorStoreIds?.append(
                            vectorStore.id)

                        // Update the assistant to save the association
                        self.updateAssistant()
                        self.successMessage = SuccessMessage(
                            message: "Vector Store created and associated successfully.")
                    case .failure(let error):
                        self.handleError(
                            IdentifiableError(
                                message:
                                    "Failed to create vector store: \(error.localizedDescription)"))
                    }
                }
            }
        }
    }

    // MARK: - Success Message Struct

    // Structure for displaying success messages to the user.
    struct SuccessMessage: Identifiable {
        let id = UUID()
        let message: String
    }
}
