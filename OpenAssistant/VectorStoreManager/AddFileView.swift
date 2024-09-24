import SwiftUI
import UniformTypeIdentifiers

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
        .edgesIgnoringSafeArea(.all)
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
            Task {
                await uploadFilesConcurrently()
            }
        }
        .disabled(selectedFiles.isEmpty || isUploading)
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

    private func uploadFilesConcurrently() async {
        isUploading = true
        defer { isUploading = false }

        let maxSize = 10 * 1024 * 1024 // 10MB limit per file
        var fileIds: [String] = []

        await withTaskGroup(of: String?.self) { group in
            for fileURL in selectedFiles {
                group.addTask {
                    await self.uploadFile(fileURL, maxSize)
                }
            }

            for await result in group {
                if let fileId = result {
                    fileIds.append(fileId)
                }
            }
        }

        if !fileIds.isEmpty {
            await createFileBatch(fileIds)
        } else {
            showError("No files were uploaded successfully.")
        }
    }

    private func uploadFile(_ fileURL: URL, _ maxSize: Int) async -> String? {
        do {
            guard fileURL.startAccessingSecurityScopedResource() else {
                showError("Failed to access file at \(fileURL).")
                return nil
            }
            defer { fileURL.stopAccessingSecurityScopedResource() }

            let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            if fileSize > maxSize {
                showError("File \(fileURL.lastPathComponent) is too large. Maximum allowed size is 10MB.")
                return nil
            }

            let fileData = try Data(contentsOf: fileURL)
            let fileName = fileURL.lastPathComponent

            return try await withCheckedThrowingContinuation { continuation in
                viewModel.addFileToVectorStore(vectorStoreId: vectorStore.id, fileData: fileData, fileName: fileName) { result in
                    switch result {
                    case .success:
                        continuation.resume(returning: fileName)
                    case .failure(let error):
                        self.showError("Failed to upload file \(fileName): \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                    }
                }
            }
        } catch {
            showError("Failed to read or upload file data for \(fileURL.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private func createFileBatch(_ fileIds: [String]) async {
        await withCheckedContinuation { continuation in
            viewModel.createFileBatch(vectorStoreId: vectorStore.id, fileIds: fileIds) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("Files successfully uploaded.")
                    case .failure(let error):
                        self.showError("Failed to create file batch: \(error.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func showError(_ message: String) {
        errorMessage = "Error occurred: " + message
        print("Debug Log: \(message)")
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
