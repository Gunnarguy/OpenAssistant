import Foundation
import Combine
import SwiftUI

class AssistantManagerViewModel: ObservableObject {
    @Published var assistants: [Assistant] = []
    @Published var availableModels: [String] = []
    @Published var vectorStores: [VectorStore] = []
    @Published var errorMessage: String?
    
    private var openAIService: OpenAIService?
    private var cancellables = Set<AnyCancellable>()
    
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""
    
    init() {
        initializeOpenAIService()
        fetchAssistants()
        fetchAvailableModels() // Ensure models are fetched on initialization
        fetchVectorStores() // Ensure vector stores are fetched on initialization
    }
    
    // MARK: - Initialization
    
    private func initializeOpenAIService() {
        guard !apiKey.isEmpty else {
            handleError("API key is missing")
            return
        }
        openAIService = OpenAIService(apiKey: apiKey)
    }
    
    // MARK: - Actions
    
    func fetchAssistants() {
        performServiceAction { openAIService in
            openAIService.fetchAssistants { [weak self] (result: Result<[Assistant], OpenAIServiceError>) in
                DispatchQueue.main.async {
                    self?.handleFetchResult(result)
                }
            }
        }
    }
    
    func fetchAvailableModels() {
        performServiceAction { openAIService in
            openAIService.fetchAvailableModels { [weak self] (result: Result<[String], Error>) in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let models):
                        // Filter models to include only those that are variations of gpt-3.5 and gpt-4
                        self?.availableModels = models.filter { $0.contains("gpt-3.5") || $0.contains("gpt-4") }
                    case .failure(let error):
                        self?.handleError("Fetch models failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func fetchVectorStores() {
        guard let openAIService = openAIService else {
            handleError("OpenAIService is not initialized")
            return
        }
        
        openAIService.fetchVectorStores()
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    DispatchQueue.main.async {
                        self?.handleError("Fetch vector stores failed: \(error.localizedDescription)")
                    }
                }
            }, receiveValue: { [weak self] vectorStores in
                DispatchQueue.main.async {
                    self?.vectorStores = vectorStores
                }
            })
            .store(in: &cancellables)
    }
    
    func createAssistant(model: String, name: String, description: String?, instructions: String?, tools: [Tool], toolResources: ToolResources?, metadata: [String: String]?, temperature: Double, topP: Double, responseFormat: ResponseFormat?) {
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
            ) { [weak self] (result: Result<Assistant, OpenAIServiceError>) in
                DispatchQueue.main.async {
                    self?.handleCreateResult(result)
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
            ) { [weak self] (result: Result<Assistant, OpenAIServiceError>) in
                DispatchQueue.main.async {
                    self?.handleUpdateResult(result)
                }
            }
        }
    }
    
    func deleteAssistant(assistant: Assistant) {
        performServiceAction { openAIService in
            openAIService.deleteAssistant(assistantId: assistant.id) { [weak self] (result: Result<Void, OpenAIServiceError>) in
                DispatchQueue.main.async {
                    self?.handleDeleteResult(result)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performServiceAction(action: (OpenAIService) -> Void) {
        guard let openAIService = openAIService else {
            handleError("OpenAIService is not initialized")
            return
        }
        action(openAIService)
    }
    
    private func handleFetchResult(_ result: Result<[Assistant], OpenAIServiceError>) {
        switch result {
        case .success(let assistants):
            self.assistants = assistants
        case .failure(let error):
            handleError("Fetch failed: \(error.localizedDescription)")
        }
    }
    
    private func handleCreateResult(_ result: Result<Assistant, OpenAIServiceError>) {
        switch result {
        case .success(let assistant):
            self.assistants.append(assistant)
            NotificationCenter.default.post(name: .assistantCreated, object: assistant)
        case .failure(let error):
            handleError("Create failed: \(error.localizedDescription)")
        }
    }
    
    private func handleUpdateResult(_ result: Result<Assistant, OpenAIServiceError>) {
        switch result {
        case .success(let updatedAssistant):
            if let index = self.assistants.firstIndex(where: { $0.id == updatedAssistant.id }) {
                self.assistants[index] = updatedAssistant
                NotificationCenter.default.post(name: .assistantUpdated, object: updatedAssistant)
            }
        case .failure(let error):
            handleError("Update failed: \(error.localizedDescription)")
        }
    }
    
    private func handleDeleteResult(_ result: Result<Void, OpenAIServiceError>) {
        switch result {
        case .success:
            // Handle successful deletion if needed
            NotificationCenter.default.post(name: .assistantDeleted, object: nil)
        case .failure(let error):
            handleError("Delete failed: \(error.localizedDescription)")
        }
    }
    
    private func handleError(_ message: String) {
        errorMessage = message
        print("Error: \(message)")
    }
}


