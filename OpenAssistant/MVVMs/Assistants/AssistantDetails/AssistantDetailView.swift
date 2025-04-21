import Combine
import SwiftUI

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

    // Computed property to check if the current assistant uses a model where updates are restricted
    private var isUpdateRestrictedModel: Bool {
        let modelId = viewModel.assistant.model.lowercased()
        return modelId.starts(with: "o1") || modelId.starts(with: "o3")
            || modelId.starts(with: "o4") || modelId == "gpt-4o-mini"  // Add gpt-4o-mini
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
                Section {
                    Button("Save Changes") {
                        viewModel.updateAssistant()
                    }
                    // Disable the button if it's a restricted model
                    .disabled(isUpdateRestrictedModel || viewModel.isLoading)

                    // Show explanation if disabled
                    if isUpdateRestrictedModel {
                        Text(
                            "Note: Assistants using O-series models (o1, o3, o4) or gpt-4o-mini cannot be updated due to current API limitations. The API may change the model unexpectedly. To make changes, please create a new assistant with the desired configuration."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("Delete Assistant", role: .destructive) {
                        viewModel.deleteAssistant()
                        dismissView()  // Dismiss after initiating delete
                    }
                    .disabled(viewModel.isLoading)
                }
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
                        // Disable toolbar save button for restricted models as well
                        .disabled(isUpdateRestrictedModel || viewModel.isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delete", action: handleDelete)
                        // Also disable delete while loading
                        .disabled(viewModel.isLoading)
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
            .onChange(of: managerViewModel.availableModels) { _ in
                initializeModel()  // Ensure model bound to current list
            }
            .onDisappear(perform: onDisappear)
            .navigationDestination(isPresented: $showVectorStoreDetail) {
                VectorStoreDetailView(
                    viewModel: vectorStoreManagerViewModel,
                    vectorStore: vectorStore
                        ?? VectorStore(
                            id: "", name: "", description: "", status: "", usageBytes: 0,
                            createdAt: 0,
                            fileCounts: FileCounts(
                                inProgress: 0, completed: 0, failed: 0, cancelled: 0, total: 0),
                            metadata: nil, expiresAfter: nil, expiresAt: nil, lastActiveAt: nil,
                            files: nil),
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

    // Save assistant if fields valid
    private func handleSave() {
        // Validate assistant details before proceeding
        if validateAssistant() {
            print(
                "Saving assistant with ID: \(viewModel.assistant.id), model: \(viewModel.assistant.model)"
            )
            // Call update on the manager view model, which handles API call and completion
            managerViewModel.updateAssistant(assistant: viewModel.assistant) { result in
                // Switch to main thread for UI updates
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // Dismiss the view on successful update
                        self.dismissView()
                    case .failure(let error):
                        // Show an alert if the update fails
                        self.showAlert(
                            message: "Failed to update assistant: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // Show an alert if validation fails
            showAlert(message: "Please fill in all required fields.")
        }
    }

    private func handleDelete() {
        managerViewModel.deleteAssistant(assistant: viewModel.assistant)
        dismissView()
    }

    // Ensure name and model are non-empty and valid
    private func validateAssistant() -> Bool {
        // Only check for non-empty name and model
        let nameValid = !viewModel.assistant.name.trimmingCharacters(in: .whitespaces).isEmpty
        let modelValid = !viewModel.assistant.model.isEmpty
        return nameValid && modelValid
    }

    private func dismissView() {
        presentationMode.wrappedValue.dismiss()
    }

    // Initialize model selection to first available if current is invalid
    private func initializeModel() {
        if !managerViewModel.availableModels.contains(viewModel.assistant.model),
            let first = managerViewModel.availableModels.first
        {
            viewModel.assistant.model = first
        }
    }

    private func updateVectorStore(with updatedStores: [VectorStore]) {
        if let store = updatedStores.first(where: {
            $0.id == viewModel.assistant.tool_resources?.fileSearch?.vectorStoreIds?.first
        }) {
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

            // Associated Vector Store IDs Section
            Section(header: Text("Associated Vector Store IDs")) {
                if let vectorStoreIds = viewModel.assistant.tool_resources?.fileSearch?
                    .vectorStoreIds, !vectorStoreIds.isEmpty
                {
                    ForEach(vectorStoreIds, id: \.self) { id in
                        HStack {
                            Text(id)
                            Spacer()
                            Button(action: {
                                viewModel.deleteVectorStoreId(id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                } else {
                    Text("No associated vector store IDs.")
                }
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
