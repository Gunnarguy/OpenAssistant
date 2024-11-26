import Foundation
import Combine
import SwiftUI

@MainActor
class AssistantDetailViewModel: BaseViewModel {
    @Published var assistant: Assistant

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
}
