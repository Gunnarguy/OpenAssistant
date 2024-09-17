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
                assistantId: self.assistant.id,
                model: self.assistant.model,
                name: self.assistant.name,
                description: self.assistant.description,
                instructions: self.assistant.instructions,
                tools: self.assistant.tools.map { $0.toDictionary() },
                toolResources: self.assistant.tool_resources?.toDictionary(),
                metadata: self.assistant.metadata,
                temperature: self.assistant.temperature,
                topP: self.assistant.top_p
            ) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handleUpdateResult(result)
                }
            }
        }
    }

    func deleteAssistant() {
        performServiceAction { openAIService in
            openAIService.deleteAssistant(assistantId: self.assistant.id) { [weak self] result in
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
            self.assistant = updatedAssistant
            NotificationCenter.default.post(name: .assistantUpdated, object: updatedAssistant)
        case .failure(let error):
            handleError("Update failed: \(error.localizedDescription)")
        }
    }
    
    private func handleDeleteResult(_ result: Result<Void, OpenAIServiceError>) {
        switch result {
        case .success:
            NotificationCenter.default.post(name: .assistantDeleted, object: self.assistant)
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

struct AssistantDetailView: View {
    @StateObject private var viewModel: AssistantDetailViewModel
    
    init(assistant: Assistant) {
        _viewModel = StateObject(wrappedValue: AssistantDetailViewModel(assistant: assistant))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if let errorMessage = viewModel.errorMessage {
                    Text(" \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                Text("Details for \(viewModel.assistant.name)")
                    .font(.title)
                    .padding()
                FormFieldsView(assistant: $viewModel.assistant)
                SlidersView(assistant: $viewModel.assistant)
                ActionButtonsView(
                    updateAction: viewModel.updateAssistant,
                    deleteAction: viewModel.deleteAssistant
                )
            }
            .padding()
        }
        .onReceive(NotificationCenter.default.publisher(for: .assistantDeleted)) { _ in
            viewModel.handleError("Assistant deleted successfully")
        }
    }
}

struct FormFieldsView: View {
    @Binding var assistant: Assistant
    
    var body: some View {
        Form {
            Section(header: Text("Basic Information")) {
                TextField("Name", text: $assistant.name)
                TextField("Instructions", text: Binding($assistant.instructions, default: ""))
                TextField("Model", text: $assistant.model)
                TextField("Description", text: Binding($assistant.description, default: ""))
            }
        }
    }
}

struct SlidersView: View {
    @Binding var assistant: Assistant
    
    var body: some View {
        VStack {
            Slider(value: $assistant.temperature, in: 0...2, step: 0.1) {
                Text("Temperature")
            }
            Slider(value: $assistant.top_p, in: 0...1, step: 0.1) {
                Text("Top P")
            }
        }
    }
}

struct ActionButtonsView: View {
    let updateAction: () -> Void
    let deleteAction: () -> Void
    
    var body: some View {
        HStack {
            Button(action: updateAction) {
                Text("Update")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            Button(action: deleteAction) {
                Text("Delete")
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
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
