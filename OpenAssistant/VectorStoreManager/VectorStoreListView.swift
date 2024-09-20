import Foundation
import Combine
import SwiftUI

struct VectorStoreListView: View {
    @StateObject var viewModel = VectorStoreManagerViewModel()

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
            }
            .navigationTitle("Vector Stores")
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
                // Automatically updates the view since `vectorStores` is published
            })
            .store(in: &viewModel.cancellables)
    }

    private func formattedDate(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(bytes) bytes"
        }
    }
}