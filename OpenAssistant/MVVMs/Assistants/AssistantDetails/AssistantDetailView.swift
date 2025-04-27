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

    var body: some View {
        NavigationStack {
            Form {
                // Core Details & Generation Settings
                AssistantDetailsSection(
                    assistant: $viewModel.assistant,
                    availableModels: managerViewModel.availableModels
                )
                // Capabilities (Tools)
                AssistantToolsSection(assistant: $viewModel.assistant)

                // Vector Store Management (Refined)
                VectorStoreManagementSection(
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

    // MARK: - Assistant Tools Section (Refined)
    struct AssistantToolsSection: View {
        @Binding var assistant: Assistant

        var body: some View {
            Section(header: Text("Capabilities")) {  // Consistent header
                Toggle(isOn: toolBinding(for: "file_search")) {
                    Label("Enable File Search", systemImage: "doc.text.magnifyingglass")
                }
                Toggle(isOn: toolBinding(for: "code_interpreter")) {
                    Label("Enable Code Interpreter", systemImage: "curlybraces.square")
                }
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

// MARK: - Vector Store Management Section (Refined)
struct VectorStoreManagementSection: View {
    @ObservedObject var viewModel: AssistantDetailViewModel
    var vectorStore: VectorStore?  // The primary associated vector store details
    @ObservedObject var vectorStoreManagerViewModel: VectorStoreManagerViewModel  // For listing/creating
    @Binding var showVectorStoreDetail: Bool
    @Binding var vectorStoreName: String  // For creating new
    var onCreateVectorStore: () -> Void

    @State private var vectorStoreIdToAssociate: String = ""  // For manual association
    @State private var showAssociationOptions = false  // To toggle create/manual section

    // Computed property to get the primary associated ID (if any)
    private var primaryVectorStoreId: String? {
        viewModel.assistant.tool_resources?.fileSearch?.vectorStoreIds?.first
    }

    var body: some View {
        Section(header: Label("File Search Vector Store", systemImage: "folder.fill")) {

            // --- Display Current Association ---
            VStack(alignment: .leading, spacing: 10) {
                if let currentId = primaryVectorStoreId {
                    Text("Currently Associated Store").font(.headline)
                    if let store = vectorStore, store.id == currentId {
                        // Display details if we have the fetched VectorStore object
                        InfoRow(label: "Name", value: store.name ?? "Unnamed", icon: "tag")
                        InfoRow(label: "ID", value: store.id, icon: "number", truncate: .middle)
                        InfoRow(
                            label: "Created", value: formattedDate(from: store.createdAt),
                            icon: "calendar")

                        // Actions for the current store
                        HStack {
                            // View Details Button
                            Button {
                                showVectorStoreDetail = true
                            } label: {
                                Label("View Files", systemImage: "doc.richtext")
                            }
                            .buttonStyle(.bordered).tint(.accentColor)

                            Spacer()  // Pushes buttons apart

                            // Remove Association Button
                            Button(role: .destructive) {
                                viewModel.deleteVectorStoreId(currentId)
                            } label: {
                                Label("Remove", systemImage: "xmark.bin")
                            }
                            .buttonStyle(.bordered).tint(.red)
                        }
                        .padding(.top, 5)

                    } else {
                        // Fallback if VectorStore object isn't loaded yet, just show ID
                        InfoRow(label: "ID", value: currentId, icon: "number", truncate: .middle)
                        Text("Loading details...")
                            .font(.caption).foregroundColor(.secondary)
                        // Add remove button here too
                        Button(role: .destructive) {
                            viewModel.deleteVectorStoreId(currentId)
                        } label: {
                            Label("Remove Association", systemImage: "xmark.bin")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).tint(.red)
                        .padding(.top, 5)
                    }
                } else {
                    // --- No Store Associated ---
                    Text("No vector store associated for File Search.")
                        .foregroundColor(.secondary)
                        .italic()
                    // Button to reveal association options
                    Button {
                        showAssociationOptions.toggle()
                    } label: {
                        Label("Associate a Vector Store", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.blue)
                }
            }
            .padding(.vertical, 8)

            // --- Association Options (Conditional) ---
            // Show if no store is associated OR if user explicitly wants to change
            if primaryVectorStoreId == nil || showAssociationOptions {
                // Create New Store Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create & Associate New").font(.subheadline).bold()
                    HStack {
                        Image(systemName: "square.and.pencil").foregroundColor(.secondary)
                        TextField("New Vector Store Name", text: $vectorStoreName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    Button(action: onCreateVectorStore) {
                        Label("Create and Associate", systemImage: "plus.app.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(.green)  // Less prominent than primary action
                    .disabled(vectorStoreName.isEmpty)
                }
                .padding(.vertical, 8)

                // Manual Association Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Associate Existing by ID").font(.subheadline).bold()
                    HStack {
                        Image(systemName: "link").foregroundColor(.secondary)
                        TextField("Existing Vector Store ID", text: $vectorStoreIdToAssociate)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    Button {
                        viewModel.saveVectorStoreId(vectorStoreIdToAssociate)
                        vectorStoreIdToAssociate = ""  // Clear field after associating
                        showAssociationOptions = false  // Hide options after associating
                    } label: {
                        Label("Associate This ID", systemImage: "link.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(.orange)  // Different color for distinction
                    .disabled(vectorStoreIdToAssociate.isEmpty)
                }
                .padding(.vertical, 8)
            }
            // Optionally add a button to explicitly show/hide association options if one is already set
            else if primaryVectorStoreId != nil {
                Button {
                    showAssociationOptions.toggle()
                } label: {
                    Label(
                        showAssociationOptions
                            ? "Hide Association Options" : "Associate Different Store",
                        systemImage: showAssociationOptions
                            ? "chevron.up.square" : "chevron.down.square"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 5)
            }

            // --- List All Associated IDs (Optional - maybe for debug/advanced) ---
            // Consider hiding this behind another toggle if it gets noisy
            // if let vectorStoreIds = viewModel.assistant.tool_resources?.fileSearch?.vectorStoreIds, vectorStoreIds.count > 1 {
            //     Divider()
            //     VStack(alignment: .leading) {
            //         Text("All Associated IDs (\(vectorStoreIds.count))").font(.caption).foregroundColor(.secondary)
            //         ForEach(vectorStoreIds, id: \.self) { id in
            //             HStack {
            //                 Text(id)
            //                     .font(.caption2)
            //                     .truncationMode(.middle)
            //                 Spacer()
            //                 if id != primaryVectorStoreId { // Don't show delete for the primary one here
            //                     Button { viewModel.deleteVectorStoreId(id) } label: {
            //                         Image(systemName: "trash.circle").foregroundColor(.red)
            //                     }
            //                     .buttonStyle(.plain)
            //                 }
            //             }
            //         }
            //     }
            //     .padding(.vertical, 8)
            // }
        }
        // Removed the local alert as success/error handling is managed by the ViewModel's alerts
    }

    // ... Helper View InfoRow and formattedDate ...
    // Helper View for Info Rows
    private struct InfoRow: View {
        let label: String
        let value: String
        let icon: String
        var truncate: Text.TruncationMode = .tail

        var body: some View {
            HStack {
                Label(label, systemImage: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)  // Adjusted width slightly
                Text(value)
                    .lineLimit(1)
                    .truncationMode(truncate)
                Spacer()
            }
            .font(.subheadline)
        }
    }

    // Formats timestamp to a readable date string
    private func formattedDate(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
