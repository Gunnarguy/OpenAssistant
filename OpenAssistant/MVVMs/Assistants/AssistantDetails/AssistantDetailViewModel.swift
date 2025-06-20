import Combine
import Foundation
import SwiftUI

@MainActor
class AssistantDetailViewModel: BaseViewModel {
    @Published var assistant: Assistant
    @Published var isLoading = false
    @Published var successMessage: SuccessMessage?
    private var cancellables = Set<AnyCancellable>()

    init(assistant: Assistant) {
        self.assistant = assistant
        super.init()
        setupNotificationObservers()
    }

    // MARK: - Notification Observers

    // Set up observers for external assistant updates to refresh this view's data
    private func setupNotificationObservers() {
        let notificationCenter = NotificationCenter.default

        // Listen for updates to any assistant to refresh our specific assistant data
        notificationCenter.publisher(for: .assistantUpdated)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let updatedAssistant = notification.object as? Assistant,
                    updatedAssistant.id == self.assistant.id
                {
                    // Use the notification object directly for immediate UI updates
                    // This prevents race conditions with server fetches
                    print(
                        "Assistant updated via notification: \(updatedAssistant.reasoning_effort ?? "nil"), current: \(self.assistant.reasoning_effort ?? "nil")"
                    )
                    self.assistant = updatedAssistant
                    // Force a UI update by triggering objectWillChange
                    self.objectWillChange.send()
                } else {
                    // Fallback: refresh from server if notification doesn't contain assistant object
                    print("Notification without matching assistant object, fetching latest details")
                    self.fetchLatestAssistantDetails()
                }
            }
            .store(in: &cancellables)

        // Also listen for the didUpdateAssistant notification for updates from other views
        notificationCenter.publisher(for: .didUpdateAssistant)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let updatedAssistant = notification.object as? Assistant,
                    updatedAssistant.id == self.assistant.id
                {
                    // Use the notification object directly
                    print(
                        "Assistant updated via didUpdateAssistant notification: \(updatedAssistant.reasoning_effort ?? "nil")"
                    )
                    self.assistant = updatedAssistant
                    // Force a UI update by triggering objectWillChange
                    self.objectWillChange.send()
                } else {
                    // Fallback: refresh from server for non-specific notifications
                    print(
                        "didUpdateAssistant notification without matching assistant, fetching latest details"
                    )
                    self.fetchLatestAssistantDetails()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch Latest Assistant Details

    // Fetches the latest assistant details from the server to ensure UI is up-to-date
    func fetchLatestAssistantDetails() {
        print("Fetching latest assistant details for ID: \(assistant.id)")
        performServiceAction { openAIService in
            openAIService.fetchAssistantDetails(assistantId: assistant.id) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let latestAssistant):
                        print(
                            "Successfully refreshed assistant details from server. Reasoning effort: \(latestAssistant.reasoning_effort ?? "nil")"
                        )
                        self.assistant = latestAssistant
                        // Force a UI update by triggering objectWillChange
                        self.objectWillChange.send()
                    case .failure(let error):
                        print("Failed to refresh assistant details: \(error.localizedDescription)")
                    // Don't show error for background refresh, just log it
                    }
                }
            }
        }
    }

    // MARK: - Update Assistant

    // Updates the assistant's details via the API service.
    // Added completion handler for asynchronous feedback.
    func updateAssistant(completion: ((Result<Void, Error>) -> Void)? = nil) {
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
            "Parameters to send - Temp: \(tempToSend?.description ?? "nil"), TopP: \(topPToSend?.description ?? "nil"), Reasoning: \(reasoningToSend?.description ?? "nil")"
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

                        // Update the assistant object immediately to ensure UI reflects changes
                        self.assistant = updatedAssistant
                        print(
                            "Local assistant updated with reasoning_effort: \(self.assistant.reasoning_effort ?? "nil")"
                        )

                        // Force UI update
                        self.objectWillChange.send()

                        // Post the standard notification with the updated assistant object
                        NotificationCenter.default.post(
                            name: .assistantUpdated, object: updatedAssistant)

                        // Only set generic success message if no completion handler is provided
                        // or if the completion handler doesn't handle specific messages.
                        if completion == nil {
                            self.successMessage = SuccessMessage(
                                message: "Assistant updated successfully.")
                        }
                        // Call completion handler on success
                        completion?(.success(()))

                    case .failure(let error):
                        // ... existing error handling ...
                        let errorMessage = "Update assistant failed: \(error.localizedDescription)"
                        print("ERROR: \(errorMessage)")
                        self.fetchLatestAssistantDetails()  // Revert local state
                        self.handleError(IdentifiableError(message: errorMessage))
                        // Call completion handler on failure
                        completion?(.failure(error))
                    }
                }
            }
        }
    }

    // MARK: - Delete Assistant

    // Deletes the current assistant.
    func deleteAssistant() {
        performServiceAction { openAIService in
            openAIService.deleteAssistant(assistantId: assistant.id) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("Successfully deleted assistant.")
                        // Post both notification types for broader compatibility
                        NotificationCenter.default.post(
                            name: .assistantDeleted, object: self?.assistant)
                        NotificationCenter.default.post(name: .didUpdateAssistant, object: nil)
                    case .failure(let error):
                        self?.handleError(
                            IdentifiableError(
                                message: "Failed to delete assistant: \(error.localizedDescription)"
                            ))
                    }
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
        // Pass a completion handler to set a specific success message
        updateAssistant { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.successMessage = SuccessMessage(
                        message: "Vector Store associated successfully.",
                        didAssociateVectorStore: true  // Indicate VS association
                    )
                case .failure:
                    // Error is handled within updateAssistant, just don't show success
                    break
                }
            }
        }
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
        // Pass a completion handler to set a specific success message
        updateAssistant { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.successMessage = SuccessMessage(
                        message: "Vector Store association removed successfully.",
                        didAssociateVectorStore: true  // Indicate VS change
                    )
                case .failure:
                    // Error is handled within updateAssistant
                    break
                }
            }
        }
    }

    // Creates a new vector store and associates it with the assistant.
    func createAndAssociateVectorStore(name: String) {
        performServiceAction { openAIService in
            self.isLoading = true
            openAIService.createVectorStore(name: name) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }  // Ensure self is available
                    self.isLoading = false  // Stop loading indicator regardless of outcome

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
                        // Use the completion handler to set the success message *after* update confirms
                        self.updateAssistant { [weak self] updateResult in
                            DispatchQueue.main.async {
                                switch updateResult {
                                case .success:
                                    self?.successMessage = SuccessMessage(
                                        message:
                                            "Vector Store created and associated successfully.",
                                        didAssociateVectorStore: true  // Set the flag
                                    )

                                    // Post notification with the newly created vector store for immediate UI update
                                    NotificationCenter.default.post(
                                        name: .vectorStoreCreatedAndAssociated,
                                        object: vectorStore
                                    )

                                case .failure(let updateError):
                                    // Handle the update failure specifically if needed,
                                    // otherwise the general error handling in updateAssistant might suffice.
                                    print(
                                        "Failed to update assistant after creating vector store: \(updateError.localizedDescription)"
                                    )
                                // Error is already handled by updateAssistant's failure case
                                }
                            }
                        }

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
    // Conforms to Equatable to be used with onChange.
    struct SuccessMessage: Identifiable, Equatable {  // Add Equatable conformance
        let id = UUID()
        let message: String
        var didAssociateVectorStore: Bool = false  // Flag for VS association
    }
}
