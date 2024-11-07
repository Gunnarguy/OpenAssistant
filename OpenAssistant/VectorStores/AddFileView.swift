import SwiftUI
import Foundation
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
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""

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
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { resetErrorState() }
        } message: {
            Text(errorMessage)
        }
    }

    private var fileSelectionText: some View {
        Text(selectedFiles.isEmpty ? "No files selected" : "Selected \(selectedFiles.count) file(s)")
    }

    private var selectFilesButton: some View {
        Button("Select Files") { isFilePickerPresented = true }
    }

    private var uploadFilesButton: some View {
        Button("Upload Files") { startUploadTask() }
            .disabled(selectedFiles.isEmpty || isUploading)
    }

    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedFiles = urls
            if urls.isEmpty {
                Task { @MainActor in
                    await showError("No files selected.")
                }
            }
        case .failure(let error):
            Task { @MainActor in
                await showError("File selection failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func startUploadTask() {
        uploadTask = Task {
            do {
                try await uploadFilesConcurrently()
            } catch is CancellationError {
                await showError("Upload was canceled.")
            } catch {
                await showError("Upload failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadFile(_ fileURL: URL, maxSize: Int) async throws -> String? {
        guard fileURL.startAccessingSecurityScopedResource() else {
            await showError("Failed to access file at \(fileURL).")
            return nil
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }
        
        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize <= maxSize else {
            await showError("File \(fileURL.lastPathComponent) is too large.")
            return nil
        }
        
        let fileData = try Data(contentsOf: fileURL)
        guard !fileData.isEmpty else {
            await showError("File \(fileURL.lastPathComponent) is empty or cannot be read.")
            return nil
        }
        
        let fileName = fileURL.lastPathComponent
        print("Uploading file: \(fileName) with size: \(fileSize) bytes")
        
        do {
            let fileId = try await viewModel.addFileToVectorStoreAsync(
                vectorStoreId: vectorStore.id,
                fileData: fileData,
                fileName: fileName
            )
            print("Successfully uploaded \(fileName) with ID: \(fileId)")
            return fileId
        } catch {
            print("Upload failed for \(fileName): \(error)")
            await showError("Failed to upload file \(fileName): \(error.localizedDescription)")
            throw error
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
                } else {
                    print("File upload returned nil fileId for a file")
                }
            }
        }
        
        if fileIds.isEmpty {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No files were uploaded successfully."])
        }
        
        print("All files uploaded successfully with IDs: \(fileIds)")
    }
    
    @MainActor
    private func showError(_ message: String) async {
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
