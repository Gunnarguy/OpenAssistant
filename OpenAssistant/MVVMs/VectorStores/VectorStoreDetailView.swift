import Combine
import Foundation
import SwiftUI

struct VectorStoreDetailView: View {
    @ObservedObject var viewModel: VectorStoreManagerViewModel
    let vectorStore: VectorStore
    @Binding var isAddingFile: Bool
    @Binding var didDeleteFile: Bool

    @State private var files: [VectorStoreFile] = []
    @State private var searchText = ""
    @State private var cancellables = Set<AnyCancellable>()
    @State private var alert: AlertData?
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var chunkSize: Int = 800  // Default chunk size
    @State private var overlapSize: Int = 400  // Default overlap size

    var body: some View {
        List {
            VectorStoreDetailsSection(vectorStore: vectorStore)
            FileCountsSection(fileCounts: vectorStore.fileCounts, actualFiles: files)
            FilesSection(files: filteredFiles, isLoading: isLoading, onDelete: deleteFile)
            AddFileSection(isAddingFile: $isAddingFile)
        }
        .navigationTitle(vectorStore.name ?? "Vector Store Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                refreshButton
            }
        }
        .onAppear {
            // Delay to prevent UI update conflicts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                loadFiles()
            }
        }
        .sheet(isPresented: $isAddingFile) {
            NavigationView {
                AddFileView(
                    viewModel: viewModel, vectorStoreId: vectorStore, chunkSize: $chunkSize,
                    overlapSize: $overlapSize
                )
                .navigationTitle("Add Files")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isAddingFile = false
                        }
                    }
                }
            }
            .onDisappear {
                // Refresh files when AddFileView is dismissed to update counts
                loadFiles()
                if didDeleteFile {
                    didDeleteFile = false  // Reset the flag
                }
            }
        }
        .onChange(of: isAddingFile) { newValue in
            print("isAddingFile changed to: \(newValue)")
        }
        .alert(item: $alert) { alert in
            Alert(
                title: Text(alert.title), message: Text(alert.message),
                dismissButton: .default(Text("OK")))
        }
        .searchable(text: $searchText, prompt: "Search files")
        .refreshable {
            await refreshFiles()
        }
    }

    // MARK: - Helper Methods
    private func loadFiles() {
        // Prevent multiple simultaneous loads
        guard !isLoading else { return }

        isLoading = true
        viewModel.fetchFiles(for: vectorStore)
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveCompletion: { completion in
                // Always update isLoading first
                self.isLoading = false

                if case .failure(let error) = completion {
                    // Delay showing alert to prevent presentation conflicts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showAlert(
                            title: "Error",
                            message: "Failed to load files: \(error.localizedDescription)")
                    }
                }
            })
            .catch { error -> AnyPublisher<[VectorStoreFile], Never> in
                // Return empty array on error after showing alert
                return Just([]).eraseToAnyPublisher()
            }
            .sink(receiveValue: { newFiles in
                self.files = newFiles
            })
            .store(in: &cancellables)
    }

    private func refreshFiles() async {
        // Prevent multiple simultaneous refreshes
        guard !isRefreshing && !isLoading else {
            return
        }

        isRefreshing = true

        return await withCheckedContinuation { continuation in
            viewModel.fetchFiles(for: vectorStore)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        isRefreshing = false
                        if case .failure(let error) = completion {
                            // Delay showing alert to prevent presentation conflicts
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showAlert(
                                    title: "Error",
                                    message:
                                        "Failed to refresh files: \(error.localizedDescription)")
                            }
                        }
                        continuation.resume()
                    },
                    receiveValue: { fetchedFiles in
                        self.files = fetchedFiles
                    }
                )
                .store(in: &cancellables)
        }
    }

    private func deleteFile(at offsets: IndexSet) {
        // Create a local copy of the indices to delete to avoid index changes during deletion
        let filesToDelete = offsets.map { files[$0] }

        for file in filesToDelete {
            // Optimistically remove from UI immediately
            if let index = self.files.firstIndex(where: { $0.id == file.id }) {
                self.files.remove(at: index)
            }

            viewModel.deleteFileFromVectorStore(vectorStoreId: vectorStore.id, fileId: file.id)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            DispatchQueue.main.async {
                                // Re-add the file back if deletion failed
                                self.files.append(file)
                                self.showAlert(
                                    title: "Error",
                                    message: "Failed to delete file: \(error.localizedDescription)")
                            }
                        }
                    },
                    receiveValue: { _ in
                        DispatchQueue.main.async {
                            print(
                                "File \(file.id) successfully deleted from vector store \(self.vectorStore.id)"
                            )
                            self.didDeleteFile = true

                            // Delay refresh to give API time to process deletion
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                self.loadFiles()
                            }
                        }
                    }
                )
                .store(in: &cancellables)
        }
    }

    private func showAlert(title: String, message: String) {
        // Set alert state in a thread-safe way
        DispatchQueue.main.async {
            self.alert = AlertData(title: title, message: message)
        }
    }

    private var filteredFiles: [VectorStoreFile] {
        if searchText.isEmpty {
            return files
        } else {
            return files.filter { file in
                file.id.localizedCaseInsensitiveContains(searchText)
                    || file.object.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var refreshButton: some View {
        Button(action: loadFiles) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.7)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(isLoading || isRefreshing)
    }
}

// MARK: - Reusable Views

struct VectorStoreDetailsSection: View {
    let vectorStore: VectorStore

    var body: some View {
        Section(header: Text("Details")) {
            Text("Name: \(vectorStore.name ?? "Unnamed Vector Store")")
            HStack {
                Text("ID: \(vectorStore.id)")  // Display the vector store ID
                Button(action: {
                    UIPasteboard.general.string = vectorStore.id
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Copy ID")
            }
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
    let actualFiles: [VectorStoreFile]  // Pass current files array for real-time count

    // Calculate dynamic counts based on actual files
    private var dynamicCounts:
        (inProgress: Int, completed: Int, failed: Int, cancelled: Int, total: Int)
    {
        let inProgress = actualFiles.filter { $0.status == "in_progress" }.count
        let completed = actualFiles.filter { $0.status == "completed" }.count
        let failed = actualFiles.filter { $0.status == "failed" }.count
        let cancelled = actualFiles.filter { $0.status == "cancelled" }.count
        let total = actualFiles.count

        return (inProgress, completed, failed, cancelled, total)
    }

    var body: some View {
        Section(header: Text("File Counts")) {
            let counts = dynamicCounts

            HStack {
                Text("In Progress:")
                Spacer()
                Text("\(counts.inProgress)")
                    .foregroundColor(counts.inProgress > 0 ? .blue : .secondary)
            }

            HStack {
                Text("Completed:")
                Spacer()
                Text("\(counts.completed)")
                    .foregroundColor(counts.completed > 0 ? .green : .secondary)
            }

            HStack {
                Text("Failed:")
                Spacer()
                Text("\(counts.failed)")
                    .foregroundColor(counts.failed > 0 ? .red : .secondary)
            }

            HStack {
                Text("Cancelled:")
                Spacer()
                Text("\(counts.cancelled)")
                    .foregroundColor(counts.cancelled > 0 ? .orange : .secondary)
            }

            Divider()

            HStack {
                Text("Total:")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(counts.total)")
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
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
                        VStack(alignment: .leading) {
                            Text("ID: \(file.id)")
                        }
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
            Button(action: {
                print("Add File button tapped, setting isAddingFile to true")
                isAddingFile = true
            }) {
                Label("Add File", systemImage: "plus.circle")
            }
            .disabled(isAddingFile)  // Prevent multiple taps while sheet is opening
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

    private func formatBytes(_ bytes: Int?) -> String {
        guard let bytes = bytes else { return "N/A" }
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

// MARK: - Alert Data Model

struct AlertData: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
