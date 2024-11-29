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
                .onChange(of: vectorStoreManagerViewModel.vectorStores) { updatedStores in
                    updateVectorStore(with: updatedStores)
                }
                AssistantToolsSection(assistant: $viewModel.assistant)
                VectorStoreManagementSection(viewModel: viewModel)
            }
            .navigationTitle("Update Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: dismissView)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: handleSave)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delete", action: handleDelete)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
        }
    }

    private var filteredModels: [String] {
        let chatModels = ["gpt-4o"]
        return managerViewModel.availableModels.filter { chatModels.contains($0) }
    }

    private func handleSave() {
        if validateAssistant() {
            print("Saving assistant with ID: \(viewModel.assistant.id)")
            viewModel.updateAssistant()
            managerViewModel.updateAssistant(assistant: viewModel.assistant) { result in
                switch result {
                case .success:
                    dismissView()
                case .failure(let error):
                    showAlert(message: "Failed to update assistant: \(error.localizedDescription)")
                }
            }
        } else {
            showAlert(message: "Please fill in all required fields.")
        }
    }

    private func handleDelete() {
        managerViewModel.deleteAssistant(assistant: viewModel.assistant)
        dismissView()
    }

    private func validateAssistant() -> Bool {
        let isValidName = !viewModel.assistant.name.trimmingCharacters(in: .whitespaces).isEmpty
        let isValidModel = filteredModels.contains(viewModel.assistant.model)
        return isValidName && isValidModel
    }

    private func dismissView() {
        presentationMode.wrappedValue.dismiss()
    }

    private func initializeModel() {
        if !filteredModels.contains(viewModel.assistant.model) {
            if filteredModels.contains("gpt-4, gpt-3.5") {
                viewModel.assistant.model = "gpt-4, gpt-3.5"
            } else if let firstModel = filteredModels.first {
                viewModel.assistant.model = firstModel
            }
        }
    }

    private func updateVectorStore(with updatedStores: [VectorStore]) {
        if let store = updatedStores.first(where: { $0.id == viewModel.assistant.tool_resources?.fileSearch?.vectorStoreIds?.first }) {
            vectorStore = store
        }
    }

    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }

    private func onAppear() {
        managerViewModel.fetchAvailableModels()
        initializeModel()
    }

    private func onDisappear() {
        if isAddingFile || didDeleteFile {
            // Handle any necessary actions on disappear
        }
    }

    struct AssistantToolsSection: View {
        @Binding var assistant: Assistant

        var body: some View {
            Section(header: Text("Tools")) {
                Toggle("Enable File Search", isOn: toolBinding(for: "file_search"))
                Toggle("Enable Code Interpreter", isOn: toolBinding(for: "code_interpreter"))
            }
        }

        private func toolBinding(for type: String) -> Binding<Bool> {
            Binding(
                get: {
                    assistant.tools.contains { $0.type == type }
                },
                set: { isEnabled in
                    updateToolState(isEnabled: isEnabled, type: type)
                }
            )
        }

        private func updateToolState(isEnabled: Bool, type: String) {
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

struct VectorStoreManagementSection: View {
    @ObservedObject var viewModel: AssistantDetailViewModel
    @State private var vectorStoreId: String = ""

    var body: some View {
        Section(header: Text("Vector Store Management")) {
            TextField("Vector Store ID", text: $vectorStoreId)
            HStack {
                Button("Save Vector Store ID") {
                    viewModel.saveVectorStoreId(vectorStoreId)
                }
                Button("Delete Vector Store ID") {
                    viewModel.deleteVectorStoreId(vectorStoreId)
                }
            }
        }
    }
}
