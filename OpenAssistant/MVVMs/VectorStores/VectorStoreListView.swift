import Foundation
import Combine
import SwiftUI

// MARK: - VectorStoreListView
struct VectorStoreListView: View {
    @ObservedObject var viewModel = VectorStoreManagerViewModel()
    @State private var isShowingCreateAlert = false
    @State private var newVectorStoreName = ""
    @State private var isAddingFile = false
    @State private var didDeleteFile = false
    @State private var isLoading = false
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
            .alert("Create New Vector Store", isPresented: $isShowingCreateAlert, actions: {
                createAlertActions
            }, message: {
                Text("Enter a name for the new vector store.")
            })
            .onAppear(perform: loadVectorStores)
            .onReceive(NotificationCenter.default.publisher(for: .settingsUpdated)) { _ in
                loadVectorStores()
            }
            .alert(item: $viewModel.errorMessage) { error in
                Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
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
            if viewModel.vectorStores.isEmpty {
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
                        VectorStoreRow(vectorStore: vectorStore)
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
                (store.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                store.id.localizedCaseInsensitiveContains(searchText)
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
            Button("Cancel", role: .cancel, action: {})
        }
    }

    private func loadVectorStores() {
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
                return Just([]).eraseToAnyPublisher()
            }
            .assign(to: \.vectorStores, on: viewModel)
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

    private func createVectorStore() {
        guard !newVectorStoreName.isEmpty else {
            viewModel.showNotification(message: "Vector store name cannot be empty.")
            return
        }

        viewModel.createVectorStore(name: newVectorStoreName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("Successfully created vector store.")
                        isShowingCreateAlert = false
                        newVectorStoreName = ""
                        loadVectorStores()
                    case .failure(let error):
                        print("Error creating vector store: \(error.localizedDescription)")
                        viewModel.errorMessage = IdentifiableError(message: error.localizedDescription)
                    }
                },
                receiveValue: { vectorStoreId in
                    print("Vector Store Created with ID: \(vectorStoreId)")
                }
            )
            .store(in: &viewModel.cancellables)
    }
}

// MARK: - VectorStoreRow
struct VectorStoreRow: View {
    let vectorStore: VectorStore

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
            Label("\(vectorStore.fileCounts.total)", systemImage: "doc.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if vectorStore.fileCounts.inProgress > 0 {
                Label("\(vectorStore.fileCounts.inProgress)", systemImage: "arrow.triangle.2.circlepath")
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
