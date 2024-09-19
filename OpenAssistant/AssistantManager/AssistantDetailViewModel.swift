import Foundation
import Combine
import SwiftUI

class AssistantDetailViewModel: ObservableObject {
    @Published var assistant: Assistant
    @Published var errorMessage: String?
    private var openAIService: OpenAIService?
    private var cancellables = Set<AnyCancellable>()
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "OpenAI_API_Key") ?? ""
    }
    
    init(assistant: Assistant) {
        self.assistant = assistant
        initializeOpenAIService()
    }
    
    private func initializeOpenAIService() {
        guard !apiKey.isEmpty else {
            handleError("API key is missing")
            return
        }
        openAIService = OpenAIService(apiKey: apiKey)
    }
    
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
                DispatchQueue.main.async {
                    self?.handleUpdateResult(result)
                }
            }
        }
    }

    func deleteAssistant() {
        performServiceAction { openAIService in
            openAIService.deleteAssistant(assistantId: assistant.id) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleDeleteResult(result)
                }
            }
        }
    }
    
    private func performServiceAction(action: (OpenAIService) -> Void) {
        guard let openAIService = openAIService else {
            handleError("OpenAIService is not initialized")
            return
        }
        action(openAIService)
    }
    
    private func handleUpdateResult(_ result: Result<Assistant, OpenAIServiceError>) {
        switch result {
        case .success(let updatedAssistant):
            assistant = updatedAssistant
            NotificationCenter.default.post(name: .assistantUpdated, object: updatedAssistant)
        case .failure(let error):
            handleError("Update failed: \(error.localizedDescription)")
        }
    }
    
    private func handleDeleteResult(_ result: Result<Void, OpenAIServiceError>) {
        switch result {
        case .success:
            NotificationCenter.default.post(name: .assistantDeleted, object: assistant)
            handleError("Assistant deleted successfully")
        case .failure(let error):
            handleError("Delete failed: \(error.localizedDescription)")
        }
    }
    
    func handleError(_ message: String) {
        errorMessage = message
        print("Error: \(message)")
    }
}



extension Binding {
    init(_ source: Binding<Value?>, default defaultValue: Value) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { newValue in source.wrappedValue = newValue }
        )
    }
}

extension Notification.Name {
    static let assistantUpdated = Notification.Name("assistantUpdated")
    static let assistantDeleted = Notification.Name("assistantDeleted")
    static let assistantCreated = Notification.Name("assistantCreated")
}
