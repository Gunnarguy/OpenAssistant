import SwiftUI
import Combine
import UniformTypeIdentifiers

struct AddFileView: View {
    @ObservedObject var viewModel: VectorStoreManagerViewModel
    let vectorStore: VectorStore
    @State private var selectedFiles: [URL] = []
    @State private var isFilePickerPresented = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isUploading = false
    @State private var uploadTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 20) {
            fileSelectionText
            selectFilesButton
            uploadFilesButton
            cancelUploadButton
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

    private var fileSelectionText: some View {
        Text(selectedFiles.isEmpty ? "No files selected" : "Selected files: \(selectedFiles.map { $0.lastPathComponent }.joined(separator: ", "))")
    }

    private var selectFilesButton: some View {
        Button("Select Files") {
            isFilePickerPresented = true
        }
    }

    private var uploadFilesButton: some View {
        Button("Upload Files") {
            startUploadTask()
        }
        .disabled(selectedFiles.isEmpty || isUploading)
    }

    private var cancelUploadButton: some View {
        Button("Cancel Upload") {
            uploadTask?.cancel()
        }
        .disabled(!isUploading)
    }

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

    private func startUploadTask() {
        uploadTask = Task {
            do {
                try await uploadFilesConcurrently()
            } catch {
                showError("Upload failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadFile(_ fileURL: URL, maxSize: Int) async throws -> String? {
        guard fileURL.startAccessingSecurityScopedResource() else {
            showError("Failed to access file at \(fileURL).")
            return nil
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }

        let fileData = try Data(contentsOf: fileURL)
        guard !fileData.isEmpty else {
            showError("File \(fileURL.lastPathComponent) is empty or cannot be read.")
            return nil
        }

        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        if fileSize > maxSize {
            showError("File \(fileURL.lastPathComponent) is too large.")
            return nil
        }

        let fileName = fileURL.lastPathComponent
        print("Uploading file: \(fileName) with size: \(fileSize) bytes")

        return try await withCheckedThrowingContinuation { continuation in
            viewModel.addFileToVectorStore(vectorStoreId: vectorStore.id, fileData: fileData, fileName: fileName)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Upload failed for \(fileName): \(error)")
                        self.showError("Failed to upload file \(fileName): \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                    }
                }, receiveValue: { fileId in
                    print("Successfully uploaded \(fileName) with ID: \(fileId)")
                    continuation.resume(returning: fileId)
                })
                .store(in: &viewModel.cancellables)
        }
    }

    private func uploadFilesConcurrently() async throws {
        isUploading = true
        defer { isUploading = false }

        let maxSize = 10 * 1024 * 1024 // 10MB limit per file
        var fileIds: [String] = []

        try await withThrowingTaskGroup(of: String?.self) { group in
            for fileURL in selectedFiles {
                group.addTask {
                    return try await self.uploadFile(fileURL, maxSize: maxSize)
                }
            }

            for try await fileId in group {
                if let fileId = fileId {
                    fileIds.append(fileId)
                }
            }
        }

        if fileIds.isEmpty {
            throw OpenAIServiceError.custom("No files were uploaded successfully.")
        }

        print("All files uploaded successfully with IDs: \(fileIds)")
    }

    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }

    private func resetErrorState() {
        showErrorAlert = false
        errorMessage = ""
    }

    private var allowedContentTypes: [UTType] {
        return [UTType.pdf, UTType.plainText, UTType.image, UTType.json]
    }
}
