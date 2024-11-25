import Foundation
import SwiftUI
import Combine

struct AssistantDetailView: View {
    @StateObject private var viewModel: AssistantDetailViewModel
    @ObservedObject private var vectorStoreManagerViewModel = VectorStoreManagerViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var vectorStore: VectorStore?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showVectorStoreDetail = false
    @ObservedObject var managerViewModel: AssistantManagerViewModel
    @State private var isAddingFile = false
    @State private var didDeleteFile = false

    // Custom initializer for injecting the Assistant and ManagerViewModel
    init(assistant: Assistant, managerViewModel: AssistantManagerViewModel) {
        _viewModel = StateObject(wrappedValue: AssistantDetailViewModel(assistant: assistant))
        self.managerViewModel = managerViewModel
    }

    var body: some View {
        NavigationView {
            Form {
                AssistantDetailsSection(
                    assistant: $viewModel.assistant,
                    availableModels: managerViewModel.availableModels,
                    showVectorStoreDetail: $showVectorStoreDetail,
                    vectorStoreManagerViewModel: vectorStoreManagerViewModel
                )
                AssistantToolsSection(assistant: $viewModel.assistant)
            }
            .navigationTitle("Update Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismissView()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        handleSave()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delete") {
                        handleDelete()
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                managerViewModel.fetchAvailableModels()
                initializeModel()
            }
            .onDisappear {
                if isAddingFile || didDeleteFile {
                    // Handle any necessary actions on disappear
                }
            }
            .sheet(isPresented: $showVectorStoreDetail) {
                if let vectorStore = vectorStore {
                    VectorStoreDetailView(
                        viewModel: vectorStoreManagerViewModel,
                        vectorStore: vectorStore,
                        isAddingFile: $isAddingFile,
                        didDeleteFile: $didDeleteFile
                    )
                }
            }
        }
    }
    
    var filteredModels: [String] {
        let chatModels = ["gpt-4o"]
        return managerViewModel.availableModels.filter { chatModels.contains($0) }
    }
    
    func handleSave() {
        if validateAssistant() {
            managerViewModel.updateAssistant(assistant: viewModel.assistant) { result in
                switch result {
                case .success:
                    dismissView()
                case .failure(let error):
                    alertMessage = "Failed to update assistant: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        } else {
            alertMessage = "Please fill in all required fields."
            showAlert = true
        }
    }
    
    func handleDelete() {
        managerViewModel.deleteAssistant(assistant: viewModel.assistant)
        dismissView()
    }
    
    func validateAssistant() -> Bool {
        let isValidName = !viewModel.assistant.name.trimmingCharacters(in: .whitespaces).isEmpty
        let isValidModel = filteredModels.contains(viewModel.assistant.model)
        return isValidName && isValidModel
    }
    
    func dismissView() {
        presentationMode.wrappedValue.dismiss()
    }
    
    func initializeModel() {
        if !filteredModels.contains(viewModel.assistant.model) {
            if filteredModels.contains("gpt-4, gpt-3.5") {
                viewModel.assistant.model = "gpt-4, gpt-3.5"
            } else if let firstModel = filteredModels.first {
                viewModel.assistant.model = firstModel
            }
        }
    }
    
    struct AssistantToolsSection: View {
        @Binding var assistant: Assistant
        
        var body: some View {
            Section(header: Text("Tools")) {
                Toggle("Enable File Search", isOn: Binding(
                    get: {
                        assistant.tools.contains { $0.type == "file_search" }
                    },
                    set: { isEnabled in
                        updateToolState(isEnabled: isEnabled, type: "file_search")
                    }
                ))
                Toggle("Enable Code Interpreter", isOn: Binding(
                    get: {
                        assistant.tools.contains { $0.type == "code_interpreter" }
                    },
                    set: { isEnabled in
                        updateToolState(isEnabled: isEnabled, type: "code_interpreter")
                    }
                ))
            }
        }
        
        func updateToolState(isEnabled: Bool, type: String) {
            if isEnabled {
                if !assistant.tools.contains(where: { $0.type == type }) {
                    assistant.tools.append(Tool(type: type))
                }
            } else {
                assistant.tools.removeAll { $0.type == type }
            }
        }
    }
}
