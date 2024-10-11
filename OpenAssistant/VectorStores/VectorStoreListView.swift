import Foundation
import Combine
import SwiftUI

// MARK: - VectorStoreListView
struct VectorStoreListView: View {
    @ObservedObject var viewModel = VectorStoreManagerViewModel()
    @State private var isShowingCreateAlert = false
    @State private var newVectorStoreName = ""
    @State private var newVectorStoreFiles: [File] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.vectorStores) { vectorStore in
                    NavigationLink(destination: VectorStoreDetailView(viewModel: viewModel, vectorStore: vectorStore)) {
                        VectorStoreRow(vectorStore: vectorStore)
                    }
                }
                .onDelete(perform: deleteVectorStore)
            }
            .navigationTitle("Vector Stores")
            
            .alert("Create New Vector Store", isPresented: $isShowingCreateAlert, actions: {
                createAlertActions
            }, message: {
                Text("Enter a name for the new vector store and select files.")
            })
            .onAppear(perform: loadVectorStores)
            .onReceive(NotificationCenter.default.publisher(for: .settingsUpdated)) { _ in
                loadVectorStores()
            }
            .alert(item: $viewModel.errorMessage) { error in
                Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
            }
            .refreshable {
                loadVectorStores()
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
        viewModel.fetchVectorStores()
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("Failed to fetch vector stores: \(error)")
                    viewModel.errorMessage = IdentifiableError(message: error.localizedDescription)
                }
            }, receiveValue: { vectorStores in
                viewModel.vectorStores = vectorStores
            })
            .store(in: &viewModel.cancellables)
    }

    private func deleteVectorStore(at offsets: IndexSet) {
        offsets.forEach { index in
            let vectorStore = viewModel.vectorStores[index]
            viewModel.deleteVectorStore(vectorStoreId: vectorStore.id)
        }
    }

    private func createVectorStore() {
        // Implement the logic to create a new vector store
    }
}

// MARK: - VectorStoreRow
struct VectorStoreRow: View {
    let vectorStore: VectorStore

    var body: some View {
        VStack(alignment: .leading) {
            Text(vectorStore.name ?? "Unnamed Vector Store")
                .font(.headline)
            Text("Created at: \(formattedDate(from: vectorStore.createdAt))")
                .font(.subheadline)
        }
    }

    private func formattedDate(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
