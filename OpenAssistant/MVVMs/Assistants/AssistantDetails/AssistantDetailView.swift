import Combine
import SwiftUI

// Removed incorrect imports for non-existent modules
// import AssistantToolsSectionView
// import VectorStoreManagementView

struct AssistantDetailView: View {
    @StateObject private var viewModel: AssistantDetailViewModel
    @StateObject private var vectorStoreManagerViewModel = VectorStoreManagerViewModel()
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
    @State private var shouldShowAddFileView = false

    init(assistant: Assistant, managerViewModel: AssistantManagerViewModel) {
        _viewModel = StateObject(wrappedValue: AssistantDetailViewModel(assistant: assistant))
        self.managerViewModel = managerViewModel
    }

    // Computed property to generate a unique ID for forcing view recreation
    private var assistantViewId: String {
        let baseId = viewModel.assistant.id
        let tempString = String(viewModel.assistant.temperature)
        let topPString = String(viewModel.assistant.top_p)
        let reasoningEffort = viewModel.assistant.reasoning_effort ?? ""
        return baseId + tempString + topPString + reasoningEffort
    }

    var body: some View {
        NavigationStack {
            Form {
                // Core Details & Generation Settings
                AssistantDetailsSection(
                    assistant: $viewModel.assistant,
                    availableModels: managerViewModel.availableModels,
                    viewModel: viewModel
                )
                // Capabilities (Tools) - Use extracted view
                AssistantToolsSectionView(assistant: $viewModel.assistant, viewModel: viewModel)

                // Vector Store Management (Refined) - Use extracted view
                VectorStoreManagementView(
                    viewModel: viewModel,
                    vectorStore: vectorStore,
                    vectorStoreManagerViewModel: vectorStoreManagerViewModel,
                    showVectorStoreDetail: $showVectorStoreDetail,
                    vectorStoreName: $vectorStoreName,
                    onCreateVectorStore: createVectorStore
                )

                // Delete Button Section (Redesigned)
                Section {
                    VStack(spacing: 10) {
                        Text("Danger Zone")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text("Permanently remove this assistant and all of its data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 5)

                        Button(action: handleDelete) {
                            Label("Delete Assistant", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(viewModel.isLoading)
                        .padding(.horizontal, 40)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color(.systemGroupedBackground))
            }
            .id(assistantViewId)  // Force view recreation when key properties change
            .onChange(of: vectorStoreManagerViewModel.vectorStores) { updatedStores in
                updateVectorStore(with: updatedStores)
            }
            .navigationTitle("Update Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: dismissView)
                }

                // Add Save button to the navigation bar's trailing position
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        handleSave()
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
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
                initializeModel()
            }
            .onChange(of: viewModel.assistant.reasoning_effort) { newValue in
                print("AssistantDetailView detected reasoning_effort change: \(newValue ?? "nil")")
            }
            .onChange(of: viewModel.assistant) { newAssistant in
                print(
                    "AssistantDetailView detected assistant object change - reasoning_effort: \(newAssistant.reasoning_effort ?? "nil")"
                )
            }
            .onDisappear(perform: onDisappear)
            .navigationDestination(isPresented: $showVectorStoreDetail) {
                VectorStoreDetailViewWrapper(
                    viewModel: vectorStoreManagerViewModel,
                    vectorStore: vectorStore
                        ?? VectorStore(
                            id: "", name: "", description: "", status: "", usageBytes: 0,
                            createdAt: 0,
                            fileCounts: FileCounts(
                                inProgress: 0, completed: 0, failed: 0, cancelled: 0, total: 0),
                            metadata: nil, expiresAfter: nil, expiresAt: nil, lastActiveAt: nil,
                            files: nil),
                    parentDidDeleteFile: $didDeleteFile
                )
                .onAppear {
                    print("VectorStoreDetailView appeared from AssistantDetailView")
                    // Ensure vector store manager is ready when VectorStoreDetailView appears
                    vectorStoreManagerViewModel.initializeAndFetch()
                }
                .onDisappear {
                    print("VectorStoreDetailView disappeared")
                }
            }
            // Add onChange modifier to react to success messages indicating VS association
            .onChange(of: viewModel.successMessage) { successInfo in
                // Check if the success message indicates a vector store association
                if let success = successInfo, success.didAssociateVectorStore {
                    print(
                        "Detected vector store association success, refreshing vector stores list.")
                    // Use initializeAndFetch to subscribe internally and update vectorStores
                    vectorStoreManagerViewModel.initializeAndFetch()
                }
            }
            // Add notification observer for newly created and associated vector stores
            .onReceive(NotificationCenter.default.publisher(for: .vectorStoreCreatedAndAssociated))
            { notification in
                if let newVectorStore = notification.object as? VectorStore {
                    print(
                        "Received notification for newly created vector store: \(newVectorStore.id)"
                    )

                    // Add the new vector store to the manager's list immediately (avoid duplicates)
                    if !vectorStoreManagerViewModel.vectorStores.contains(where: {
                        $0.id == newVectorStore.id
                    }) {
                        vectorStoreManagerViewModel.vectorStores.insert(newVectorStore, at: 0)
                    }

                    // Update the local vectorStore variable immediately for UI display
                    vectorStore = newVectorStore

                    print("Vector store UI updated immediately - can now tap 'View Files'")
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
            // Use the completion handler to dismiss the view only after a successful update.
            // This prevents a race condition where the user navigates away before the
            // update notification is processed.
            viewModel.updateAssistant { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // Dismiss the view upon successful save.
                        self.presentationMode.wrappedValue.dismiss()
                    case .failure(let error):
                        // Show an alert if the update fails.
                        self.showAlert(
                            message: "Failed to update assistant: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            showAlert(message: "Assistant name and model cannot be empty.")
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
        print(
            "AssistantDetailView onAppear - current reasoning_effort: \(viewModel.assistant.reasoning_effort ?? "nil")"
        )
        managerViewModel.fetchAvailableModels()
        initializeModel()
        // Ensure vector store manager is properly initialized
        vectorStoreManagerViewModel.initializeAndFetch()

        // ALWAYS refresh assistant details to ensure we have the latest data from server
        // This fixes the issue where locally cached data might be stale
        print("Refreshing assistant details from server to ensure UI shows latest values")
        viewModel.fetchLatestAssistantDetails()
    }

    private func onDisappear() {
        if isAddingFile || didDeleteFile {
        }
    }

    private func createVectorStore() {
        guard !vectorStoreName.isEmpty else { return }
        viewModel.createAndAssociateVectorStore(name: vectorStoreName)
        // Clear the name field after initiating creation
        vectorStoreName = ""
    }
}

// MARK: - VectorStoreDetailView Wrapper
/// A wrapper view that manages its own local state for the AddFileView sheet
struct VectorStoreDetailViewWrapper: View {
    @ObservedObject var viewModel: VectorStoreManagerViewModel
    let vectorStore: VectorStore
    @Binding var parentDidDeleteFile: Bool
    @State private var localIsAddingFile = false
    @State private var localDidDeleteFile = false

    var body: some View {
        VectorStoreDetailView(
            viewModel: viewModel,
            vectorStore: vectorStore,
            isAddingFile: $localIsAddingFile,
            didDeleteFile: $localDidDeleteFile
        )
        .onChange(of: localDidDeleteFile) { newValue in
            if newValue {
                parentDidDeleteFile = true
                localDidDeleteFile = false
            }
        }
    }
}

// MARK: - Preview
/// Renders AssistantDetailView with sample data
struct AssistantDetailView_Previews: PreviewProvider {
    // Sample assistant with a comprehensive configuration
    static let sampleAssistant = Assistant(
        id: "preview-1",
        object: "assistant",
        created_at: Int(Date().timeIntervalSince1970),
        name: "Preview Assistant",
        description: "This is a preview assistant for testing UI.",
        model: "gpt-3.5-turbo",
        instructions: "Sample instructions for the assistant.",
        tools: [Tool(type: "file_search")],
        top_p: 1.0,
        temperature: 0.7,
        reasoning_effort: nil,
        tool_resources: nil,
        metadata: nil,
        response_format: nil,
        file_ids: []
    )

    // Manager view model with available models
    static let managerVM: AssistantManagerViewModel = {
        let vm = AssistantManagerViewModel()
        vm.availableModels = ["gpt-3.5-turbo", "gpt-4", "o1"]
        return vm
    }()

    static var previews: some View {
        NavigationStack {
            AssistantDetailView(
                assistant: sampleAssistant,
                managerViewModel: managerVM
            )
        }
    }
}
