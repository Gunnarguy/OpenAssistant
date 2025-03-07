import SwiftUI
import Foundation
import Combine
import UniformTypeIdentifiers

// File upload status tracking
struct FileUploadStatus: Identifiable {
    let id = UUID()
    let fileName: String
    var status: UploadStatus
    var fileId: String?
    var error: String?
    
    enum UploadStatus {
        case pending
        case uploading
        case success
        case failure
    }
}

struct AddFileView: View {
    @ObservedObject var viewModel: VectorStoreManagerViewModel
    let vectorStoreId: VectorStore
    @State private var selectedFiles: [URL] = []
    @State private var isFilePickerPresented = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isUploading = false
    @State private var uploadTask: Task<Void, Never>? = nil
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""
    @State private var fileStatuses: [FileUploadStatus] = []
    @State private var showUploadSummary = false
    @State private var successCount = 0
    @State private var failureCount = 0

    var body: some View {
        VStack(spacing: 20) {
            fileSelectionText
            selectFilesButton
            uploadFilesButton
            
            if !fileStatuses.isEmpty {
                uploadProgressList
            }
            
            if showUploadSummary {
                uploadSummary
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

    private var uploadProgressList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(fileStatuses) { status in
                    HStack {
                        Text(status.fileName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        uploadStatusIndicator(for: status)
                    }
                    .padding(.horizontal)
                    
                    if let error = status.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.leading)
                    }
                }
            }
        }
        .frame(maxHeight: 200)
    }
    
    private func uploadStatusIndicator(for status: FileUploadStatus) -> some View {
        Group {
            switch status.status {
            case .pending:
                Image(systemName: "clock")
                    .foregroundColor(.gray)
            case .uploading:
                ProgressView()
                    .scaleEffect(0.7)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failure:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var uploadSummary: some View {
        VStack(spacing: 8) {
            Text("Upload Complete")
                .font(.headline)
            Text("\(successCount) succeeded • \(failureCount) failed")
                .foregroundColor(failureCount > 0 ? .red : .green)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }

    private var fileSelectionText: some View {
        Text(selectedFiles.isEmpty ? "No files selected" : "Selected \(selectedFiles.count) file(s)")
    }

    private var selectFilesButton: some View {
        Button("Select Files") { isFilePickerPresented = true }
            .buttonStyle(.borderedProminent)
    }

    private var uploadFilesButton: some View {
        Button("Upload Files") { startUploadTask() }
            .buttonStyle(.borderedProminent)
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
        // Reset status tracking
        successCount = 0
        failureCount = 0
        showUploadSummary = false
        fileStatuses = selectedFiles.map { FileUploadStatus(fileName: $0.lastPathComponent, status: .pending) }
        
        uploadTask = Task {
            do {
                try await uploadFilesConcurrently()
            } catch is CancellationError {
                await showError("Upload was canceled.")
            } catch {
                await showError("Upload failed: \(error.localizedDescription)")
            }
            showUploadSummary = true
        }
    }

    private func uploadFile(_ fileURL: URL, maxSize: Int) async throws -> String? {
        guard let statusIndex = fileStatuses.firstIndex(where: { $0.fileName == fileURL.lastPathComponent }) else {
            return nil
        }
        
        await MainActor.run {
            fileStatuses[statusIndex].status = .uploading
        }
        
        guard fileURL.startAccessingSecurityScopedResource() else {
            await MainActor.run {
                fileStatuses[statusIndex].status = .failure
                fileStatuses[statusIndex].error = "Failed to access file"
            }
            return nil
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }

        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize <= maxSize else {
            await MainActor.run {
                fileStatuses[statusIndex].status = .failure
                fileStatuses[statusIndex].error = "File is too large (max \(maxSize/1024/1024)MB)"
            }
            return nil
        }

        let fileData = try Data(contentsOf: fileURL)
        guard !fileData.isEmpty else {
            await MainActor.run {
                fileStatuses[statusIndex].status = .failure
                fileStatuses[statusIndex].error = "File is empty or cannot be read"
            }
            return nil
        }

        do {
            let fileId = try await viewModel.uploadFile(fileData: fileData, fileName: fileURL.lastPathComponent, vectorStoreId: vectorStoreId.id)
            try await viewModel.addFileToVectorStore(vectorStoreId: vectorStoreId.id, fileId: fileId)
            
            await MainActor.run {
                fileStatuses[statusIndex].status = .success
                fileStatuses[statusIndex].fileId = fileId
                successCount += 1
            }
            return fileId
        } catch {
            await MainActor.run {
                fileStatuses[statusIndex].status = .failure
                fileStatuses[statusIndex].error = error.localizedDescription
                failureCount += 1
            }
            return nil
        }
    }

    private func uploadFilesConcurrently() async throws {
        isUploading = true
        defer { isUploading = false }

        let maxSize = 10 * 1024 * 1024 // 10MB limit per file
        var successfulFileIds: [(fileName: String, fileId: String)] = []
        var failedFiles: [(fileName: String, error: Error)] = []

        // Retry settings
        let maxRetries = 2
        let retryDelay: TimeInterval = 2.0

        try await withThrowingTaskGroup(of: (fileName: String, result: Result<String?, Error>).self) { group in
            for fileURL in selectedFiles {
                group.addTask {
                    var attempt = 0
                    while attempt <= maxRetries {
                        do {
                            let fileId = try await self.uploadFile(fileURL, maxSize: maxSize)
                            return (fileName: fileURL.lastPathComponent, result: .success(fileId))
                        } catch {
                            attempt += 1
                            if attempt > maxRetries {
                                return (fileName: fileURL.lastPathComponent, result: .failure(error))
                            }
                            try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        }
                    }
                    return (fileName: fileURL.lastPathComponent, result: .failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Retry attempts exhausted."])))
                }
            }

            for try await taskResult in group {
                switch taskResult.result {
                case .success(let fileId):
                    if let fileId = fileId {
                        successfulFileIds.append((fileName: taskResult.fileName, fileId: fileId))
                        print("Successfully uploaded \(taskResult.fileName) with ID: \(fileId)")

                        // Associate file with vector store
                        do {
                            try await viewModel.addFileToVectorStore(vectorStoreId: vectorStoreId.id, fileId: fileId)
                            print("Successfully associated \(taskResult.fileName) with vector store \(vectorStoreId.id)")
                        } catch {
                            print("Failed to associate \(taskResult.fileName) with vector store: \(error.localizedDescription)")
                        }
                    }
                case .failure(let error):
                    failedFiles.append((fileName: taskResult.fileName, error: error))
                    print("Upload failed for \(taskResult.fileName): \(error.localizedDescription)")
                }
            }
        }

        // Display success and failure summaries
        if !successfulFileIds.isEmpty {
            let successDetails = successfulFileIds.map { "\($0.fileName): ID \($0.fileId)" }.joined(separator: "\n")
            print("Successfully uploaded and associated files:\n\(successDetails)")
        }

        if !failedFiles.isEmpty {
            let failureDetails = failedFiles.map { "\($0.fileName): \($0.error.localizedDescription)" }.joined(separator: "\n")
            await showError("Some files failed to upload:\n\(failureDetails)")
        }

        if successfulFileIds.isEmpty {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No files were uploaded successfully."])
        }
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
