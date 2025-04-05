import Foundation

class FileUploadService {
    let baseURL: String
    let apiKey: String
    let session: URLSession
    
    init(baseURL: String = "https://api.openai.com/v1", apiKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }
    
    func addCommonHeaders(to request: inout URLRequest) {
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
    }
    
    // Uploads a file to OpenAI and returns the file ID
    func uploadFile(fileData: Data, fileName: String) async throws -> String {
        let url = URL(string: "\(baseURL)/files")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let mimeType = "application/octet-stream"
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
        body.append("assistants\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
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
    
    // Creates a vector store and returns its ID
    func createVectorStore(name: String) async throws -> String {
        let url = URL(string: "\(baseURL)/vector_stores")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let vectorStoreId = json?["id"] as? String else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Vector Store ID not found in response"])
        }
        
        return vectorStoreId
    }
    
    // Associates a file with a vector store
    func addFileToVectorStore(vectorStoreId: String, fileId: String) async throws {
        let url = URL(string: baseURL)!.appendingPathComponent("vector_stores/\(vectorStoreId)/files")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["file_id": fileId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
