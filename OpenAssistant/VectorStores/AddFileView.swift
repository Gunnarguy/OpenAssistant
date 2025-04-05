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
    var progress: Double = 0.0 // Add progress tracking
    
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
    // Track if upload is cancelled
    @State private var isCancelled = false

    // Improved view structure
    var body: some View {
        VStack(spacing: 20) {
            fileSelectionHeaderView
            
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
        // Add navigation bar item for cancel
        .toolbar {
            if isUploading {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isCancelled = true
                        uploadTask?.cancel()
                    }
                }
            }
        }
    }

    private var fileSelectionHeaderView: some View {
        VStack(spacing: 15) {
            Text(selectedFiles.isEmpty ? "No files selected" : "Selected \(selectedFiles.count) file(s)")
                .font(.headline)
            
            HStack(spacing: 20) {
                Button("Select Files") { isFilePickerPresented = true }
                    .buttonStyle(.borderedProminent)
                
                Button("Upload Files") { startUploadTask() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedFiles.isEmpty || isUploading)
                    .opacity(selectedFiles.isEmpty || isUploading ? 0.6 : 1.0)
            }
        }
    }

    private var uploadProgressList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(fileStatuses) { status in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(status.fileName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            uploadStatusIndicator(for: status)
                        }
                        
                        // Show progress bar for uploading files
                        if status.status == .uploading {
                            ProgressView(value: status.progress)
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                        
                        if let error = status.error {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray6))
                    )
                }
            }
        }
        .frame(maxHeight: 300)
        .padding(.vertical)
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
        isCancelled = false
        fileStatuses = selectedFiles.map { FileUploadStatus(fileName: $0.lastPathComponent, status: .pending) }
        
        uploadTask = Task {
            do {
                isUploading = true
                try await uploadFilesConcurrently()
            } catch is CancellationError {
                await showError("Upload was canceled.")
            } catch {
                await showError("Upload failed: \(error.localizedDescription)")
            }
            isUploading = false
            showUploadSummary = true
        }
    }

    private func uploadFile(_ fileURL: URL) async throws -> String? {
        guard let statusIndex = fileStatuses.firstIndex(where: { $0.fileName == fileURL.lastPathComponent }) else {
            return nil
        }
        
        await MainActor.run {
            fileStatuses[statusIndex].status = .uploading
        }
        
        // Security-scoped resource handling
        guard fileURL.startAccessingSecurityScopedResource() else {
            await MainActor.run {
                fileStatuses[statusIndex].status = .failure
                fileStatuses[statusIndex].error = "Failed to access file"
            }
            return nil
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }

        // Check if file exists and can be read
        guard let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              fileSize > 0 else {
            await MainActor.run {
                fileStatuses[statusIndex].status = .failure
                fileStatuses[statusIndex].error = "File is empty or cannot be read"
            }
            return nil
        }

        // Load file data
        do {
            let fileData = try Data(contentsOf: fileURL)
            guard !fileData.isEmpty else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "File data is empty"])
            }
            
            // Update progress periodically
            await MainActor.run {
                fileStatuses[statusIndex].progress = 0.3 // Started upload
            }
            
            // Check for cancellation
            if Task.isCancelled || isCancelled {
                throw CancellationError()
            }

            // Upload file
            let fileId = try await viewModel.uploadFile(fileData: fileData, fileName: fileURL.lastPathComponent, vectorStoreId: vectorStoreId.id)
            
            await MainActor.run {
                fileStatuses[statusIndex].progress = 0.7 // File uploaded
            }
            
            // Check for cancellation again
            if Task.isCancelled || isCancelled {
                throw CancellationError()
            }
            
            // Add file to vector store
            try await viewModel.addFileToVectorStore(vectorStoreId: vectorStoreId.id, fileId: fileId)
            
            // Update status to success
            await MainActor.run {
                fileStatuses[statusIndex].status = .success
                fileStatuses[statusIndex].fileId = fileId
                fileStatuses[statusIndex].progress = 1.0
                successCount += 1
            }
            
            return fileId
        } catch {
            // Update status to failure
            await MainActor.run {
                fileStatuses[statusIndex].status = .failure
                fileStatuses[statusIndex].error = error.localizedDescription
                failureCount += 1
            }
            throw error
        }
    }

    private func uploadFilesConcurrently() async throws {
        // No file size limit - removed entirely
        var successfulFileIds: [(fileName: String, fileId: String)] = []
        var failedFiles: [(fileName: String, error: Error)] = []

        // Retry settings
        let maxRetries = 2
        let retryDelay: TimeInterval = 2.0
        
        // Calculate concurrency limit based on file count
        let maxConcurrentUploads = min(selectedFiles.count, 3) // Max 3 concurrent uploads

        try await withThrowingTaskGroup(of: (fileName: String, result: Result<String?, Error>).self, returning: Void.self) { group in
            // Add initial batch of files
            var remainingFiles = selectedFiles
            var activeUploads = 0
            
            // Helper to add a file to the upload group
            func addFileUploadTask(for fileURL: URL) {
                group.addTask {
                    var attempt = 0
                    while attempt <= maxRetries {
                        do {
                            // Fix Main Actor isolation issue by capturing the value before the closure
                            let cancelled = await MainActor.run { self.isCancelled }
                            if Task.isCancelled || cancelled {
                                throw CancellationError()
                            }
                            
                            let fileId = try await self.uploadFile(fileURL)
                            return (fileName: fileURL.lastPathComponent, result: .success(fileId))
                        } catch is CancellationError {
                            throw CancellationError()
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
                activeUploads += 1
            }
            
            // Start initial batch
            while activeUploads < maxConcurrentUploads && !remainingFiles.isEmpty {
                let fileURL = remainingFiles.removeFirst()
                addFileUploadTask(for: fileURL)
            }
            
            // Process results and add more files as capacity becomes available
            for try await taskResult in group {
                activeUploads -= 1
                
                // Process this result
                switch taskResult.result {
                case .success(let fileId):
                    if let fileId = fileId {
                        successfulFileIds.append((fileName: taskResult.fileName, fileId: fileId))
                    }
                case .failure(let error):
                    failedFiles.append((fileName: taskResult.fileName, error: error))
                }
                
                // Check if upload was cancelled - fix Main Actor isolation
                let cancelled = await MainActor.run { self.isCancelled }
                if Task.isCancelled || cancelled {
                    break
                }
                
                // Add another file if available
                if !remainingFiles.isEmpty {
                    let fileURL = remainingFiles.removeFirst()
                    addFileUploadTask(for: fileURL)
                }
                
                // If all files have been added and no more active uploads, we're done
                if remainingFiles.isEmpty && activeUploads == 0 {
                    break
                }
            }
        }

        // Display success and failure summaries
        let cancelled = await MainActor.run { self.isCancelled }
        if cancelled {
            throw CancellationError()
        }
        
        if !successfulFileIds.isEmpty {
            let successDetails = successfulFileIds.map { "\($0.fileName): ID \($0.fileId)" }.joined(separator: "\n")
            print("Successfully uploaded and associated files:\n\(successDetails)")
        }

        if !failedFiles.isEmpty {
            let failureDetails = failedFiles.map { "\($0.fileName): \($0.error.localizedDescription)" }.joined(separator: "\n")
            await showError("Some files failed to upload:\n\(failureDetails)")
        }

        if successfulFileIds.isEmpty && !isCancelled {
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
        // Support more file types - fix UTType.csv reference
        return [
            UTType.pdf, 
            UTType.plainText, 
            UTType.image, 
            UTType.json,
            UTType.html,
            UTType.rtf,
            UTType.xml,
            .init(filenameExtension: "csv") ?? UTType.data, // Fix: Use file extension initialization
            .init(filenameExtension: "md") ?? UTType.plainText,
            .init(filenameExtension: "docx") ?? UTType.data,
            .init(filenameExtension: "pptx") ?? UTType.data,
            .init(filenameExtension: "xlsx") ?? UTType.data
        ]
    }
}
