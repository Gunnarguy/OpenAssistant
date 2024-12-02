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
    @State private var vectorStoreName: String = ""

    init(assistant: Assistant, managerViewModel: AssistantManagerViewModel) {
        _viewModel = StateObject(wrappedValue: AssistantDetailViewModel(assistant: assistant))
        self.managerViewModel = managerViewModel
    }

    var body: some View {
        NavigationStack {
            Form {
                AssistantDetailsSection(
                    assistant: $viewModel.assistant,
                    availableModels: managerViewModel.availableModels
                )
                AssistantToolsSection(assistant: $viewModel.assistant)
                VectorStoreManagementSection(
                    viewModel: viewModel,
                    vectorStore: vectorStore,
                    vectorStoreManagerViewModel: vectorStoreManagerViewModel,
                    showVectorStoreDetail: $showVectorStoreDetail,
                    vectorStoreName: $vectorStoreName,
                    onCreateVectorStore: createVectorStore
                )
            }
            .onChange(of: vectorStoreManagerViewModel.vectorStores) { updatedStores in
                updateVectorStore(with: updatedStores)
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
            .navigationDestination(isPresented: $showVectorStoreDetail) {
                VectorStoreDetailView(
                    viewModel: vectorStoreManagerViewModel,
                    vectorStore: vectorStore ?? VectorStore(id: "", name: "", description: "", status: "", usageBytes: 0, createdAt: 0, fileCounts: FileCounts(inProgress: 0, completed: 0, failed: 0, cancelled: 0, total: 0), metadata: nil, expiresAfter: nil, expiresAt: nil, lastActiveAt: nil, files: nil),
                    isAddingFile: $isAddingFile,
                    didDeleteFile: $didDeleteFile
                )
            }
            .alert(item: $viewModel.successMessage) { successMessage in
                Alert(
                    title: Text("Success"),
                    message: Text(successMessage.message),
                    dismissButton: .default(Text("OK"))
                )
            }
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

    private func createVectorStore() {
        viewModel.createAndAssociateVectorStore(name: vectorStoreName)
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
    var vectorStore: VectorStore?
    @ObservedObject var vectorStoreManagerViewModel: VectorStoreManagerViewModel
    @Binding var showVectorStoreDetail: Bool
    @Binding var vectorStoreName: String
    var onCreateVectorStore: () -> Void
    
    @State private var vectorStoreId: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        Group {
            // Current Vector Store Info Section
            Section(header: Text("Current Vector Store")) {
                if let vectorStore = vectorStore {
                    Text("Name: \(vectorStore.name ?? "Unnamed")")
                    Text("ID: \(vectorStore.id)")
                    Text("Created At: \(formattedDate(from: vectorStore.createdAt))")
                    Button(action: {
                        showVectorStoreDetail = true
                    }) {
                        Text("View Details")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                } else {
                    Text("No associated vector store.")
                }
            }
            
            // Create New Vector Store Section
            Section(header: Text("Create New Vector Store")) {
                TextField("Vector Store Name", text: $vectorStoreName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: onCreateVectorStore) {
                    Text("Create and Associate Vector Store")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
            
            // Manual Association Section
            Section(header: Text("Manual Association")) {
                TextField("Vector Store ID", text: $vectorStoreId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: {
                    viewModel.saveVectorStoreId(vectorStoreId)
                    showAlert(message: "Vector Store ID saved successfully.")
                }) {
                    Text("Save Vector Store ID")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Notification"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private func formattedDate(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
