
import SwiftUI
import Combine
import UniformTypeIdentifiers

// Main View for adding files to a Vector Store
struct AddFileView: View {
    @ObservedObject var viewModel: VectorStoreManagerViewModel
    let vectorStore: VectorStore
    @State private var selectedFiles: [URL] = []
    @State private var isFilePickerPresented = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isUploading = false

    var body: some View {
        VStack(spacing: 20) {
            fileSelectionText
            selectFilesButton
            uploadFilesButton
            if isUploading {
                ProgressView("Uploading files...")
            }
        }
        .padding()
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: true,
            onCompletion: handleFileSelection
        )
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK"), action: resetErrorState))
        }
    }

    // Display selected files or a placeholder text
    private var fileSelectionText: some View {
        Text(selectedFiles.isEmpty ? "No files selected" : "Selected files: \(selectedFiles.map { $0.lastPathComponent }.joined(separator: ", "))")
    }

    // Button to trigger file selection
    private var selectFilesButton: some View {
        Button("Select Files") {
            isFilePickerPresented = true
        }
    }

    // Button to upload selected files
    private var uploadFilesButton: some View {
        Button("Upload Files") {
            Task {
                await uploadFilesConcurrently()
            }
        }
        .disabled(selectedFiles.isEmpty || isUploading)
    }

    // Handle file selection result
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedFiles = urls
            if urls.isEmpty {
                showError("No files were selected.")
            }
        case .failure(let error):
            showError("File selection failed: \(error.localizedDescription)")
        }
    }

    // Upload files concurrently with size check
    private func uploadFilesConcurrently() async {
        isUploading = true
        defer { isUploading = false }

        let maxSize = 10 * 1024 * 1024 // 10MB limit per file
        var fileIds: [String] = []

        await withTaskGroup(of: String?.self) { group in
            for fileURL in selectedFiles {
                group.addTask {
                    await self.uploadFile(fileURL, maxSize: maxSize)
                }
            }

            for await result in group {
                if let fileId = result {
                    fileIds.append(fileId)
                }
            }
        }

        if fileIds.isEmpty {
            showError("No files were uploaded successfully.")
        }
    }

    // Upload a single file to the vector store
    private func uploadFile(_ fileURL: URL, maxSize: Int) async -> String? {
        do {
            guard fileURL.startAccessingSecurityScopedResource() else {
                showError("Failed to access file at \(fileURL).")
                return nil
            }
            defer { fileURL.stopAccessingSecurityScopedResource() }

            let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            if fileSize > maxSize {
                showError("File \(fileURL.lastPathComponent) is too large. Maximum allowed size is \(maxSize) bytes.")
                return nil
            }

            let fileData = try Data(contentsOf: fileURL)
            let fileName = fileURL.lastPathComponent

            return try await withCheckedThrowingContinuation { continuation in
                viewModel.addFileToVectorStore(vectorStoreId: vectorStore.id, fileData: fileData, fileName: fileName)
                    .sink(receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            self.showError("Failed to upload file \(fileName): \(error.localizedDescription)")
                            continuation.resume(returning: nil)
                        }
                    }, receiveValue: { fileId in
                        continuation.resume(returning: fileId)
                    })
                    .store(in: &viewModel.cancellables)
            }

        } catch {
            showError("Failed to read or upload file data for \(fileURL.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    // Display error message in an alert
    private func showError(_ message: String) {
        errorMessage = "Error occurred: " + message
        showErrorAlert = true
    }

    // Reset error state after alert dismissal
    private func resetErrorState() {
        showErrorAlert = false
        errorMessage = ""
    }

    // Allowed content types for file selection
    private var allowedContentTypes: [UTType] {
        return [UTType.pdf, UTType.plainText, UTType.image, UTType.json]
    }
}

// ViewModel for managing vector stores and file operations
