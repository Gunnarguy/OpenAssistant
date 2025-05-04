import Combine
import SwiftUI

// Removed incorrect imports for non-existent modules
// import AssistantToolsSectionView
// import VectorStoreManagementView

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
                // Core Details & Generation Settings
                AssistantDetailsSection(
                    assistant: $viewModel.assistant,
                    availableModels: managerViewModel.availableModels
                )
                // Capabilities (Tools) - Use extracted view
                AssistantToolsSectionView(assistant: $viewModel.assistant)

                // Vector Store Management (Refined) - Use extracted view
                VectorStoreManagementView(
                    viewModel: viewModel,
                    vectorStore: vectorStore,
                    vectorStoreManagerViewModel: vectorStoreManagerViewModel,
                    showVectorStoreDetail: $showVectorStoreDetail,
                    vectorStoreName: $vectorStoreName,
                    onCreateVectorStore: createVectorStore
                )

                // Main Action Buttons (Save/Delete)
                Section {  // Keep in separate section for visual separation
                    HStack {
                        Spacer()
                        Button {
                            handleSave()
                        } label: {
                            Label("Save Changes", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent).tint(.blue)
                        .disabled(viewModel.isLoading)

                        Button(role: .destructive) {
                            handleDelete()
                        } label: {
                            Label("Delete Assistant", systemImage: "trash.fill")
                        }
                        .buttonStyle(.borderedProminent).tint(.red)
                        .disabled(viewModel.isLoading)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .onChange(of: vectorStoreManagerViewModel.vectorStores) { updatedStores in
                updateVectorStore(with: updatedStores)
            }
            .navigationTitle("Update Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: dismissView)
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
                initializeModel()
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
            // Add onChange modifier to react to success messages indicating VS association
            .onChange(of: viewModel.successMessage) { successInfo in
                // Check if the success message indicates a vector store association
                if let success = successInfo, success.didAssociateVectorStore {
                    print(
                        "Detected vector store association success, refreshing vector stores list.")
                    // Refresh the vector stores list in the manager
                    vectorStoreManagerViewModel.fetchVectorStores()
                }
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

    private func handleSave() {
        if validateAssistant() {
            print(
                "Saving assistant with ID: \(viewModel.assistant.id), model: \(viewModel.assistant.model)"
            )
            viewModel.updateAssistant()
        } else {
            showAlert(message: "Please fill in all required fields.")
        }
    }

    private func handleDelete() {
        managerViewModel.deleteAssistant(assistant: viewModel.assistant)
        dismissView()
    }

    private func validateAssistant() -> Bool {
        let nameValid = !viewModel.assistant.name.trimmingCharacters(in: .whitespaces).isEmpty
        let modelValid = !viewModel.assistant.model.isEmpty
        return nameValid && modelValid
    }

    private func dismissView() {
        presentationMode.wrappedValue.dismiss()
    }

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
        }
    }

    private func createVectorStore() {
        viewModel.createAndAssociateVectorStore(name: vectorStoreName)
    }
}

// MARK: - Preview
/// Renders AssistantDetailView with sample data in Xcode canvas
struct AssistantDetailView_Previews: PreviewProvider {
    // Sample assistant for preview
    static let sampleAssistant = Assistant(
        id: "preview-1",
        object: "assistant",
        created_at: Int(Date().timeIntervalSince1970),
        name: "Preview Assistant",
        description: "This is a preview assistant for testing UI.",
        model: "gpt-3.5-turbo",
        vectorStoreId: nil,
        instructions: "",
        threads: nil,
        tools: [],
        top_p: 1.0,
        temperature: 1.0,
        reasoning_effort: nil,
        tool_resources: nil,
        metadata: nil,
        response_format: nil,
        file_ids: []
    )
    // Manager view model with available models
    static let managerVM: AssistantManagerViewModel = {
        let vm = AssistantManagerViewModel()
        vm.availableModels = ["gpt-3.5-turbo", "o1"]
        return vm
    }()

    static var previews: some View {
        // Embed in NavigationStack to display navigation bar
        NavigationStack {
            AssistantDetailView(
                assistant: sampleAssistant,
                managerViewModel: managerVM
            )
        }
    }
}
