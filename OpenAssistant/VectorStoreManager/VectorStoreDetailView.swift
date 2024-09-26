import Foundation
import Combine
import SwiftUI

struct VectorStoreDetailView: View {
    @ObservedObject var viewModel: VectorStoreManagerViewModel
    let vectorStore: VectorStore
    @State private var files: [VectorStoreFile] = []
    @State private var cancellables = Set<AnyCancellable>()
    @State private var isLoading = false
    @State private var isAddingFile = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            vectorStoreDetailsSection
            fileCountsSection
            addFileSection
            filesSection
        }
        .navigationTitle(vectorStore.name ?? "Vector Store Details")
        .onAppear(perform: loadFiles)
        .sheet(isPresented: $isAddingFile) {
            AddFileView(viewModel: viewModel, vectorStore: vectorStore)
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Sections

    private var vectorStoreDetailsSection: some View {
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
    }

    private var fileCountsSection: some View {
        Section(header: Text("File Counts")) {
            Text("In Progress: \(vectorStore.fileCounts.inProgress)")
            Text("Completed: \(vectorStore.fileCounts.completed)")
            Text("Failed: \(vectorStore.fileCounts.failed)")
            Text("Cancelled: \(vectorStore.fileCounts.cancelled)")
            Text("Total: \(vectorStore.fileCounts.total)")
        }
    }

    private var addFileSection: some View {
        Section {
            Button(action: { isAddingFile = true }) {
                Label("Add File", systemImage: "plus.circle")
            }
        }
    }

    private var filesSection: some View {
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

    // MARK: - Helper Methods

    private func loadFiles() {
        if files.isEmpty {
            isLoading = true
            viewModel.fetchFiles(for: vectorStore)
                .sink(receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        showError("Failed to load files: \(error.localizedDescription)")
                    }
                }, receiveValue: { fetchedFiles in
                    self.files = fetchedFiles
                    self.isLoading = false
                })
                .store(in: &cancellables)
        }
    }

    private func deleteFile(at offsets: IndexSet) {
        offsets.sorted(by: >).forEach { index in
            let file = files[index]
            viewModel.deleteFileFromVectorStore(vectorStoreId: vectorStore.id, fileId: file.id)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        DispatchQueue.main.async {
                            self.files.remove(at: index)
                        }
                    case .failure(let error):
                        showError("Failed to delete file: \(error.localizedDescription)")
                    }
                }, receiveValue: { _ in })
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

    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
}
