import Foundation
import Combine
import SwiftUI

struct VectorStoreDetailView: View {
    @ObservedObject var viewModel: VectorStoreManagerViewModel
    let vectorStore: VectorStore
    
    @State private var files: [VectorStoreFile] = []
    @State private var cancellables = Set<AnyCancellable>()
    @State private var alert: AlertData?
    @State private var isAddingFile = false
    @State private var isLoading = false
    
    var body: some View {
        List {
            VectorStoreDetailsSection(vectorStore: vectorStore)
            FileCountsSection(fileCounts: vectorStore.fileCounts)
            FilesSection(files: files, isLoading: isLoading, onDelete: deleteFile)
            AddFileSection(isAddingFile: $isAddingFile)
        }
        .navigationTitle(vectorStore.name ?? "Vector Store Details")
        .onAppear(perform: loadFiles)
        .sheet(isPresented: $isAddingFile) {
            AddFileView(viewModel: viewModel, vectorStoreId: vectorStore)
                .onDisappear { loadFiles() }
        }
        .alert(item: $alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Helper Methods
    private func loadFiles() {
        isLoading = true
        viewModel.fetchFiles(for: vectorStore)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    showAlert(title: "Error", message: "Failed to load files: \(error.localizedDescription)")
                }
                isLoading = false
            }, receiveValue: { fetchedFiles in
                self.files = fetchedFiles
            })
            .store(in: &cancellables)
    }
    
    private func deleteFile(at offsets: IndexSet) {
        offsets.forEach { index in
            let file = files[index]
            viewModel.deleteFileFromVectorStore(vectorStoreId: vectorStore.id, fileId: file.id)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        DispatchQueue.main.async { self.files.remove(at: index) }
                    case .failure(let error):
                        showAlert(title: "Error", message: "Failed to delete file: \(error.localizedDescription)")
                    }
                }, receiveValue: { _ in })
                .store(in: &cancellables)
        }
    }
    
    private func showAlert(title: String, message: String) {
        alert = AlertData(title: title, message: message)
    }
}

// MARK: - Reusable Views

struct VectorStoreDetailsSection: View {
    let vectorStore: VectorStore
    
    var body: some View {
        Section(header: Text("Details")) {
            Text("Name: \(vectorStore.name ?? "Unnamed Vector Store")")
            if let status = vectorStore.status { Text("Status: \(status)") }
            if let usageBytes = vectorStore.usageBytes { Text("Usage: \(formatBytes(usageBytes))") }
            Text("Created At: \(formattedDate(from: vectorStore.createdAt))")
            if let lastActiveAt = vectorStore.lastActiveAt {
                Text("Last Active At: \(formattedDate(from: lastActiveAt))")
            }
        }
    }
}

struct FileCountsSection: View {
    let fileCounts: FileCounts
    
    var body: some View {
        Section(header: Text("File Counts")) {
            Text("In Progress: \(fileCounts.inProgress)")
            Text("Completed: \(fileCounts.completed)")
            Text("Failed: \(fileCounts.failed)")
            Text("Cancelled: \(fileCounts.cancelled)")
            Text("Total: \(fileCounts.total)")
        }
    }
}

struct FilesSection: View {
    let files: [VectorStoreFile]
    let isLoading: Bool
    let onDelete: (IndexSet) -> Void
    
    var body: some View {
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
                .onDelete(perform: onDelete)
            }
        }
    }
}

struct AddFileSection: View {
    @Binding var isAddingFile: Bool
    
    var body: some View {
        Section {
            Button(action: { isAddingFile = true }) {
                Label("Add File", systemImage: "plus.circle")
            }
        }
    }
}

// MARK: - Helpers

extension VectorStoreDetailsSection {
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

// MARK: - Alert Data Model

struct AlertData: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
