import Foundation

class FileUploadService {
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession
    
    init(baseURL: String = "https://api.openai.com/v1", apiKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }
    
    private func addCommonHeaders(to request: inout URLRequest) {
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
    }
    
    // Step 1: Upload the file to OpenAI API and retrieve file_id
    func uploadFile(fileData: Data, fileName: String) async throws -> String {
        // Endpoint for file uploads
        let url = URL(string: "\(baseURL)/files")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)
        
        // Prepare file upload as multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let mimeType = "application/octet-stream"  // Adjust MIME type if necessary
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
        body.append("assistants\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Execute request
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let fileId = json?["id"] as? String else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "File ID not found in response"])
        }
        
        return fileId
    }
    
    // Step 2: Associate the file with a vector store
    func createFileBatch(vectorStoreId: String, fileIds: [String]) async throws -> FileBatch {
        let url = URL(string: "\(baseURL)/vector_stores/\(vectorStoreId)/file_batches")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["file_ids": fileIds]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let fileBatch = try JSONDecoder().decode(FileBatch.self, from: data)
        return fileBatch
    }
}



// Helper Extension for Appending Multipart Data
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
