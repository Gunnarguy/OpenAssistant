import Foundation
import Combine
import SwiftUI

struct VectorStoreDetailView: View {
    @ObservedObject var viewModel: VectorStoreManagerViewModel
    let vectorStore: VectorStore
    @State private var files: [VectorStoreFile] = [] // Change to [VectorStoreFile]
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isLoading = false
    @State private var isAddingFile = false

    var body: some View {
        List {
            // Vector Store Details Section
            Section(header: Text("Details")) {
                Text("Name: \(vectorStore.name ?? "Unnamed Vector Store")")
                if let status = vectorStore.status {
                    Text("Status: \(status)")
                }
                if let usageBytes = vectorStore.usageBytes {
                    Text("Usage: \(formatBytes(usageBytes))")
                }
                Text("Created At: \(formattedDate(from: vectorStore.createdAt))")
                if let lastActiveAt = vectorStore.lastActiveAt {
                    Text("Last Active At: \(formattedDate(from: lastActiveAt))")
                }
            }

            // File Counts Section
            Section(header: Text("File Counts")) {
                Text("In Progress: \(vectorStore.fileCounts.inProgress)")
                Text("Completed: \(vectorStore.fileCounts.completed)")
                Text("Failed: \(vectorStore.fileCounts.failed)")
                Text("Cancelled: \(vectorStore.fileCounts.cancelled)")
                Text("Total: \(vectorStore.fileCounts.total)")
            }

            // Add File Section
            Section {
                Button(action: {
                    isAddingFile = true
                }) {
                    Label("Add File", systemImage: "plus.circle")
                }
            }

            // Files Section with Pagination
            Section(header: Text("Files")) {
                if isLoading {
                    ProgressView("Loading files...")
                } else if files.isEmpty {
                    Text("No files available")
                } else {
                    ForEach(files) { file in
                        NavigationLink(destination: FileDetailView(file: file)) {
                            Text("ID: \(file.id)")
                        }
                    }
                    .onDelete(perform: deleteFile)
                }
            }
        }
        .navigationTitle(vectorStore.name ?? "Vector Store Details")
        .onAppear {
            if files.isEmpty {
                isLoading = true
                viewModel.fetchFiles(for: vectorStore)
            }

            // Listen for updates to the vector store's files
            viewModel.$vectorStores
                .sink { updatedStores in
                    if let updatedStore = updatedStores.first(where: { $0.id == vectorStore.id }) {
                        self.files = updatedStore.files ?? [] // Ensure self.files is [VectorStoreFile]
                        self.isLoading = false
                    }
                }
                .store(in: &cancellables)
        }
        .sheet(isPresented: $isAddingFile) {
            AddFileView(viewModel: viewModel, vectorStore: vectorStore)
        }
    }

    private func deleteFile(at offsets: IndexSet) {
        offsets.forEach { index in
            let file = files[index]
            viewModel.deleteFileFromVectorStore(vectorStoreId: vectorStore.id, fileId: file.id)
                .sink(receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("Failed to delete file: \(error.localizedDescription)")
                    }
                }, receiveValue: {
                    files.remove(at: index)
                })
                .store(in: &cancellables)
        }
    }

    private func formattedDate(from timestamp: Int?) -> String {
        guard let timestamp = timestamp else { return "N/A" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        return String(format: "%.2f GB", gb)
    }
}
