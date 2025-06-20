import Combine
import Foundation
import SwiftUI

// MARK: - VectorStoreListView
struct VectorStoreListView: View {
    @ObservedObject var viewModel: VectorStoreManagerViewModel
    @State private var isShowingCreateAlert = false
    @State private var newVectorStoreName = ""
    @State private var isAddingFile = false
    @State private var didDeleteFile = false
    @State private var isLoading = false
    @State private var isCreatingVectorStore = false  // Add loading state for creation
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            Group {
                if isLoading && viewModel.vectorStores.isEmpty {
                    loadingView
                } else {
                    mainListView
                }
            }
            .navigationTitle("Vector Stores")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
            }
            .alert(
                "Create New Vector Store", isPresented: $isShowingCreateAlert,
                actions: {
                    createAlertActions
                },
                message: {
                    Text("Enter a name for the new vector store.")
                }
            )
            .onAppear(perform: loadVectorStores)
            .onReceive(NotificationCenter.default.publisher(for: .settingsUpdated)) { _ in
                loadVectorStores()
            }
            .alert(item: $viewModel.errorMessage) { error in
                Alert(
                    title: Text("Error"), message: Text(error.message),
                    dismissButton: .default(Text("OK")))
            }
            .searchable(text: $searchText, prompt: "Search vector stores")
            .refreshable {
                await refreshVectorStores()
            }
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)

            Text("Loading Vector Stores...")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.top, 20)
        }
    }

    private var mainListView: some View {
        List {
            // Show creating indicator if vector store is being created
            if isCreatingVectorStore {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Creating vector store...")
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowBackground(Color(.systemGroupedBackground))
            }

            if viewModel.vectorStores.isEmpty && !isCreatingVectorStore {
                emptyStateView
            } else {
                ForEach(filteredStores) { vectorStore in
                    NavigationLink(
                        destination: VectorStoreDetailView(
                            viewModel: viewModel,
                            vectorStore: vectorStore,
                            isAddingFile: $isAddingFile,
                            didDeleteFile: $didDeleteFile
                        )
                    ) {
                        VectorStoreRow(vectorStore: vectorStore, viewModel: viewModel)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.deleteVectorStore(vectorStoreId: vectorStore.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        Section {
            VStack(spacing: 20) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(.blue.opacity(0.8))

                Text("No Vector Stores Found")
                    .font(.headline)

                Text("Create a new vector store to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Create Vector Store") {
                    isShowingCreateAlert = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .listRowBackground(Color.clear)
        }
    }

    private var filteredStores: [VectorStore] {
        if searchText.isEmpty {
            return viewModel.vectorStores
        } else {
            return viewModel.vectorStores.filter { store in
                (store.name ?? "").localizedCaseInsensitiveContains(searchText)
                    || store.id.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var addButton: some View {
        Button(action: {
            isShowingCreateAlert = true
        }) {
            Image(systemName: "plus")
        }
    }

    private var createAlertActions: some View {
        Group {
            TextField("Vector Store Name", text: $newVectorStoreName)
            Button("Create", action: createVectorStore)
                .disabled(isCreatingVectorStore || newVectorStoreName.isEmpty)  // Disable while creating
            Button("Cancel", role: .cancel, action: {})
        }
    }

    private func loadVectorStores() {
        // Prevent concurrent loading operations
        guard !isLoading else { return }

        isLoading = true
        viewModel.fetchVectorStores()
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveCompletion: { completion in
                isLoading = false
                if case let .failure(error) = completion {
                    print("Failed to fetch vector stores: \(error)")
                    viewModel.errorMessage = IdentifiableError(message: error.localizedDescription)
                }
            })
            .catch { error -> AnyPublisher<[VectorStore], Never> in
                // Show error and return empty array to prevent app crash
                DispatchQueue.main.async {
                    viewModel.errorMessage = IdentifiableError(message: error.localizedDescription)
                }
                return Just([]).eraseToAnyPublisher()
            }
            .sink(receiveValue: { vectorStores in
                // Update the vector stores immediately
                viewModel.vectorStores = vectorStores
            })
            .store(in: &viewModel.cancellables)
    }

    private func refreshVectorStores() async {
        await withCheckedContinuation { continuation in
            viewModel.fetchVectorStores()
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { _ in
                        continuation.resume()
                    },
                    receiveValue: { [weak viewModel] vectorStores in
                        viewModel?.vectorStores = vectorStores
                    }
                )
                .store(in: &viewModel.cancellables)
        }
    }

    /// Creates a new vector store with real-time UI updates
    /// Shows immediate feedback to the user and optimistically updates the list
    private func createVectorStore() {
        guard !newVectorStoreName.isEmpty else {
            viewModel.showNotification(message: "Vector store name cannot be empty.")
            return
        }

        // Store the name to use in the success handler
        let storeName = newVectorStoreName

        // Set creating state for UI feedback
        isCreatingVectorStore = true

        // Clear the alert immediately for better UX
        isShowingCreateAlert = false
        newVectorStoreName = ""

        viewModel.createVectorStore(name: storeName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isCreatingVectorStore = false  // Reset creating state
                    switch completion {
                    case .finished:
                        print("Successfully created vector store.")
                    // Don't call loadVectorStores() here - we already have optimistic update
                    // The fetchNewlyCreatedVectorStore() method handles adding the new store
                    case .failure(let error):
                        print("Error creating vector store: \(error.localizedDescription)")
                        viewModel.errorMessage = IdentifiableError(
                            message: error.localizedDescription)
                        // Re-show the alert if creation failed
                        isShowingCreateAlert = true
                        newVectorStoreName = storeName
                    }
                },
                receiveValue: { vectorStoreId in
                    print("Vector Store Created with ID: \(vectorStoreId)")
                    // Optimistically fetch the newly created vector store details
                    fetchNewlyCreatedVectorStore(id: vectorStoreId)
                }
            )
            .store(in: &viewModel.cancellables)
    }

    /// Fetches and adds the newly created vector store to the list immediately
    /// This provides instant feedback rather than waiting for a full list refresh
    private func fetchNewlyCreatedVectorStore(id: String) {
        viewModel.fetchVectorStore(id: id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print(
                            "Failed to fetch newly created vector store details: \(error.localizedDescription)"
                        )
                        // Fall back to full refresh if individual fetch fails
                        loadVectorStores()
                    }
                },
                receiveValue: { newVectorStore in
                    // Add the new vector store to the beginning of the list for immediate visibility
                    viewModel.vectorStores.insert(newVectorStore, at: 0)
                }
            )
            .store(in: &viewModel.cancellables)
    }
}

// MARK: - VectorStoreRow
struct VectorStoreRow: View {
    let vectorStore: VectorStore
    @ObservedObject var viewModel: VectorStoreManagerViewModel  // Add viewModel for real-time file counts

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vectorStore.name ?? "Unnamed Vector Store")
                .font(.headline)

            HStack(spacing: 12) {
                fileCountsIndicator

                Spacer()

                Text(formattedDate(from: vectorStore.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var fileCountsIndicator: some View {
        HStack(spacing: 8) {
            // Use real-time file count from viewModel instead of stale API data
            let currentFileCount = viewModel.getCurrentFileCount(for: vectorStore.id)
            Label("\(currentFileCount)", systemImage: "doc.fill")
                .font(.caption)
                .foregroundColor(.secondary)

            if vectorStore.fileCounts.inProgress > 0 {
                Label(
                    "\(vectorStore.fileCounts.inProgress)",
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .font(.caption)
                .foregroundColor(.blue)
            }

            if vectorStore.fileCounts.failed > 0 {
                Label("\(vectorStore.fileCounts.failed)", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func formattedDate(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
