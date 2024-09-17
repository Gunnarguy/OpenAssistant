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
            Text(selectedFiles.isEmpty ? "No files selected" : "Selected files: \(selectedFiles.map { $0.lastPathComponent }.joined(separator: ", "))")
            
            Button("Select Files") {
                isFilePickerPresented = true
            }
            
            Button("Upload Files") {
                uploadFiles()
            }
            .disabled(selectedFiles.isEmpty || isUploading)
            
            if isUploading {
                ProgressView("Uploading files...")
            }
        }
        .padding()
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [UTType.data], // Specify the types of files you want to allow
            allowsMultipleSelection: true,
            onCompletion: handleFileSelection
        )
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK"), action: resetErrorState))
        }
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedFiles = urls
            if urls.isEmpty {
                showError("No files were selected.")
            } else {
                print("Selected file URLs: \(urls)")
            }
        case .failure(let error):
            showError("File selection failed: \(error.localizedDescription)")
        }
    }

    private func uploadFiles() {
        isUploading = true
        let fileIds = selectedFiles.compactMap { fileURL -> String? in
            do {
                // Copy the file to a temporary location within the app's sandbox
                let fileManager = FileManager.default
                let tempDirectory = fileManager.temporaryDirectory
                let tempFileURL = tempDirectory.appendingPathComponent(fileURL.lastPathComponent)
                
                if !fileManager.fileExists(atPath: tempFileURL.path) {
                    try fileManager.copyItem(at: fileURL, to: tempFileURL)
                }
                
                let fileData = try Data(contentsOf: tempFileURL)
                let fileName = fileURL.lastPathComponent
                print("Reading file: \(fileName) at \(tempFileURL)")
                
                var fileId: String?
                let semaphore = DispatchSemaphore(value: 0)
                viewModel.addFileToVectorStore(vectorStoreId: vectorStore.id, fileData: fileData, fileName: fileName) { result in
                    switch result {
                    case .success:
                        fileId = fileName // Assuming file name is used as ID
                    case .failure(let error):
                        self.showError("Failed to upload file: \(error.localizedDescription)")
                    }
                    semaphore.signal()
                }
                semaphore.wait()
                return fileId
            } catch {
                showError("Failed to read file data: \(error.localizedDescription)")
                print("Error reading file at \(fileURL): \(error)")
                return nil
            }
        }
        
        guard !fileIds.isEmpty else {
            isUploading = false
            return
        }
        
        viewModel.createFileBatch(vectorStoreId: vectorStore.id, fileIds: fileIds) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Files successfully uploaded.")
                case .failure(let error):
                    self.showError("Failed to create file batch: \(error.localizedDescription)")
                }
                self.isUploading = false
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
    
    private func resetErrorState() {
        showErrorAlert = false
        errorMessage = ""
    }
}
