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
                        VStack(alignment: .leading) {
                            Text(vectorStore.name ?? "Unnamed Vector Store")
                                .font(.headline)
                            Text("Created at: \(formattedDate(from: vectorStore.createdAt))")
                                .font(.subheadline)
                        }
                    }
                }
                .onDelete(perform: deleteVectorStore)
            }
            .navigationTitle("Vector Stores")
            .navigationBarItems(trailing: Button(action: {
                isShowingCreateAlert = true
            }) {
                Image(systemName: "plus")
            })
            .alert("Create New Vector Store", isPresented: $isShowingCreateAlert, actions: {
                TextField("Vector Store Name", text: $newVectorStoreName)
                Button("Create", action: {
                    createVectorStore()
                })
                Button("Cancel", role: .cancel, action: {})
            }, message: {
                Text("Enter a name for the new vector store and select files.")
            })
            .onAppear {
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
        let fileIds = newVectorStoreFiles.map { $0.id } // Assuming `File` has an `id` property
        viewModel.createVectorStoreWithFileIds(name: newVectorStoreName, fileIds: fileIds) { result in
            switch result {
            case .success(let vectorStore):
                DispatchQueue.main.async {
                    viewModel.vectorStores.append(vectorStore)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    viewModel.errorMessage = IdentifiableError(message: error.localizedDescription)
                }
            }
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