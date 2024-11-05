import Foundation
import Combine

extension OpenAIService {
    
    // MARK: - Private Helper Methods
    
    /// Creates a URLRequest with dynamic Content-Type handling for JSON and multipart requests
    private func createRequest(endpoint: String, method: String = "GET", body: [String: Any]? = nil, contentType: String? = "application/json") -> URLRequest? {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            print("Invalid URL for endpoint: \(endpoint)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        addCommonHeaders(to: &request)
        
        // Set Content-Type if provided
        if let contentType = contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        
        // Set JSON body if applicable
        if let body = body, contentType == "application/json" {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                print("Error serializing JSON: \(error)")
                return nil
            }
        }
        
        return request
    }
    
    /// Adds common headers required for OpenAI requests
    func addCommonHeaders(to request: inout URLRequest) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
    }
    
    /// Executes a URLSession data task and handles decoding the response
    private func handleURLSessionDataTask<T: Decodable>(request: URLRequest, completion: @escaping (Result<T, Error>) -> Void) {
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Request error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("No data received for request to \(request.url?.absoluteString ?? "unknown URL")")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Debug: Print response data as a string
            if let responseDataString = String(data: data, encoding: .utf8) {
                print("Response data: \(responseDataString)")
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decodedResponse))
            } catch {
                print("Decoding error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Create Vector Store
    
    func createVectorStore(parameters: [String: Any], completion: @escaping (Result<VectorStore, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/vector_stores") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: .post)

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        session.dataTask(with: request) { data, response, error in
            self.handleDataTaskResponse(data: data, response: response, error: error, completion: completion)
        }.resume()
    }

    
    // MARK: - Create Vector Store with Files
    
    func createVectorStoreWithFiles(fileIds: [String], completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "vector_stores"
        let body: [String: Any] = [
            "name": "New Vector Store",
            "description": "A vector store with files",
            "file_ids": fileIds
        ]
        
        guard let request = createRequest(endpoint: endpoint, method: "POST", body: body) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
            return
        }
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []),
                  let vectorStoreId = (jsonResponse as? [String: Any])?["id"] as? String else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create vector store."])))
                return
            }
            completion(.success(vectorStoreId))
        }.resume()
    }
    
    // MARK: - Fetch Vector Stores
    
    func fetchVectorStores() -> Future<[VectorStore], Error> {
        return Future { promise in
            let endpoint = "vector_stores"
            
            guard let request = self.createRequest(endpoint: endpoint) else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
                return
            }
            
            self.handleURLSessionDataTask(request: request) { (result: Result<VectorStoreResponse, Error>) in
                switch result {
                case .success(let response):
                    promise(.success(response.data))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Fetch Vector Store Details
    
    func fetchVectorStoreDetails(vectorStoreId: String) -> Future<VectorStore, Error> {
        return Future { promise in
            let endpoint = "vector_stores/\(vectorStoreId)"
            
            guard let request = self.createRequest(endpoint: endpoint) else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
                return
            }
            
            self.handleURLSessionDataTask(request: request, completion: promise)
        }
    }
    
    // MARK: - Fetch Files
    
    func fetchFiles(for vectorStoreId: String) -> Future<[File], Error> {
        return Future { promise in
            let endpoint = "vector_stores/\(vectorStoreId)/files"
            
            guard let request = self.createRequest(endpoint: endpoint) else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
                return
            }
            
            self.handleURLSessionDataTask(request: request) { (result: Result<VectorStoreFilesResponse, Error>) in
                switch result {
                case .success(let response):
                    promise(.success(response.data))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Upload File
    /// Uploads a file to OpenAI's file endpoint using multipart form-data
    func uploadFile(fileData: Data, fileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "files"
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let fileId = json?["id"] as? String {
                    completion(.success(fileId))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "File ID not found"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    

    func addFileToVectorStore(vectorStoreId: String, fileData: Data, fileName: String, apiKey: String, baseURL: String) -> Future<String, Error> {
        return Future<String, Error> { promise in
            guard let url = URL(string: "\(baseURL)/v1/vector_stores/\(vectorStoreId)/files") else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
            
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            // Build multipart form-data body
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body
            
            // Log the request details for debugging
            print("Request URL: \(url)")
            print("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
            print("Request Body Size: \(body.count) bytes")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let data = data else {
                    promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                // Log the response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON response: \(jsonString)")
                }
                
                do {
                    // Check for any error in the response
                    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                        promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorResponse.error.message])))
                        return
                    }
                    
                    // Decode the expected response
                    let response = try JSONDecoder().decode([String: String].self, from: data)
                    if let fileId = response["file_id"] {
                        promise(.success(fileId))
                    } else {
                        promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing file_id in response"])))
                    }
                } catch {
                    promise(.failure(error))
                }
            }.resume()
        }
    }
    
    // MARK: - Create File Batch Using file_id

    func createFileBatch(vectorStoreId: String, fileIds: [String], chunkingStrategy: ChunkingStrategy?, completion: @escaping (Result<VectorStoreFileBatch, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/vector_stores/\(vectorStoreId)/file_batches") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: .post)
        
        // Prepare the body including the fileIds
        var body: [String: Any] = ["file_ids": fileIds]
        if let chunkingStrategy = chunkingStrategy {
            body["chunking_strategy"] = chunkingStrategy.toDictionary()
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            self.handleDataTaskResponse(data: data, response: response, error: error, completion: completion)
        }.resume()
    }

    // MARK: - Retrieve File Batch

    func getFileBatch(vectorStoreId: String, batchId: String) -> AnyPublisher<VectorStoreFileBatch, Error> {
        guard let url = URL(string: "\(baseURL)/vector_stores/\(vectorStoreId)/file_batches/\(batchId)") else {
            return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: .get)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: VectorStoreFileBatch.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - List Files in File Batch

    func listFilesInFileBatch(vectorStoreId: String, batchId: String) -> AnyPublisher<[File], Error> {
        guard let url = URL(string: "\(baseURL)/vector_stores/\(vectorStoreId)/file_batches/\(batchId)/files") else {
            return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: .get)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: [File].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // Helper Method to Add Common Headers
    private func configureRequest(_ request: inout URLRequest, httpMethod: String) {
        request.httpMethod = httpMethod
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
    }

    
    // MARK: - MIME Type Helper
    
    /// Returns the appropriate MIME type for a given file extension
    func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "c": return "text/x-c"
        case "cpp": return "text/x-c++"
        case "css": return "text/css"
        case "csv": return "text/csv"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "html": return "text/html"
        case "java": return "text/x-java"
        case "js": return "text/javascript"
        case "json": return "application/json"
        case "md": return "text/markdown"
        case "pdf": return "application/pdf"
        case "php": return "text/x-php"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "py": return "text/x-python"
        case "rb": return "text/x-ruby"
        case "tex": return "text/x-tex"
        case "ts": return "application/typescript"
        case "txt": return "text/plain"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "xml": return "text/xml"
        default: return "application/octet-stream" // Fallback for unknown types
        }
    }


    
    // MARK: - Update Vector Store
    
    func modifyVectorStore(vectorStoreId: String, name: String? = nil, expiresAfter: [String: Any]? = nil, metadata: [String: String]? = nil, files: [[String: Any]]? = nil, completion: @escaping (Result<VectorStore, Error>) -> Void) {
        let endpoint = "vector_stores/\(vectorStoreId)"
        var body: [String: Any] = [:]
        
        if let name = name {
            body["name"] = name
        }
        
        if let expiresAfter = expiresAfter {
            body["expires_after"] = expiresAfter
        }
        
        if let metadata = metadata {
            body["metadata"] = metadata
        }
        
        if let files = files {
            body["files"] = files
        }
        
        guard let request = createRequest(endpoint: endpoint, method: "POST", body: body) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
            return
        }
        
        handleURLSessionDataTask(request: request, completion: completion)
    }

    
    // MARK: - Delete Vector Store
    
    func deleteVectorStore(vectorStoreId: String) -> AnyPublisher<Void, Error> {
        let endpoint = "vector_stores/\(vectorStoreId)"
        
        guard let request = createRequest(endpoint: endpoint, method: "DELETE") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                let deleteResponse = try JSONDecoder().decode(DeleteResponse.self, from: data)
                guard deleteResponse.deleted else {
                    throw URLError(.cannotParseResponse)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Delete File
    
    func deleteFile(fileID: String) -> AnyPublisher<Void, Error> {
        let endpoint = "files/\(fileID)"
        
        guard let request = createRequest(endpoint: endpoint, method: "DELETE") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { _ in () }  // Ignore the response body
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
}

// MARK: - VectorStore
/// Represents a vector store with associated files and metadata.
struct VectorStore: Identifiable, Codable {
    let id: String
    let name: String?
    let status: String?
    let usageBytes: Int?
    let createdAt: Int
    let fileCounts: FileCounts
    let metadata: [String: String]?
    let expiresAfter: ExpiresAfterType?
    let expiresAt: Int?
    let lastActiveAt: Int?
    var files: [VectorStoreFile]? // Mutable to allow updates

    private enum CodingKeys: String, CodingKey {
        case id, name, status, usageBytes = "bytes", createdAt = "created_at", fileCounts = "file_counts", metadata, expiresAfter = "expires_after", expiresAt = "expires_at", lastActiveAt = "last_active_at", files
    }
}

// MARK: - VectorStoreFile
struct VectorStoreFile: Codable, Identifiable {
    let id: String
    let object: String
    let usageBytes: Int
    let createdAt: Int
    let vectorStoreId: String
    let status: String
    let lastError: String?
    let chunkingStrategy: ChunkingStrategy?

    private enum CodingKeys: String, CodingKey {
        case id, object, usageBytes = "usage_bytes", createdAt = "created_at"
        case vectorStoreId = "vector_store_id", status, lastError = "last_error"
        case chunkingStrategy = "chunking_strategy"
    }
}

// MARK: - VectorStoreFileBatch
struct VectorStoreFileBatch: Decodable {
    let id: String
    let object: String
    let createdAt: Int
    let vectorStoreId: String
    let status: String
    let fileCounts: FileCounts

    private enum CodingKeys: String, CodingKey {
        case id, object, createdAt = "created_at", vectorStoreId = "vector_store_id", status, fileCounts = "file_counts"
    }
}

// MARK: - ChunkingStrategy
struct ChunkingStrategy: Codable {
    let type: String
    let staticStrategy: StaticStrategy?

    private enum CodingKeys: String, CodingKey {
        case type, staticStrategy = "static"
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let staticStrategy = staticStrategy {
            dict["static"] = staticStrategy.toDictionary()
        }
        return dict
    }
}

// MARK: - StaticStrategy
struct StaticStrategy: Codable {
    let maxChunkSizeTokens: Int
    let chunkOverlapTokens: Int

    private enum CodingKeys: String, CodingKey {
        case maxChunkSizeTokens = "max_chunk_size_tokens"
        case chunkOverlapTokens = "chunk_overlap_tokens"
    }

    func toDictionary() -> [String: Any] {
        return [
            "max_chunk_size_tokens": maxChunkSizeTokens,
            "chunk_overlap_tokens": chunkOverlapTokens
        ]
    }
}

// MARK: - FileCounts
struct FileCounts: Codable {
    let inProgress: Int
    let completed: Int
    let failed: Int
    let cancelled: Int
    let total: Int

    private enum CodingKeys: String, CodingKey {
        case inProgress = "in_progress", completed, failed, cancelled, total
    }
}

// MARK: - VectorStoreResponse
/// Represents a response containing multiple vector stores.
struct VectorStoreResponse: Codable {
    let data: [VectorStore]
    let firstId: String?
    let lastId: String?
    let hasMore: Bool

    private enum CodingKeys: String, CodingKey {
        case data, firstId = "first_id", lastId = "last_id", hasMore = "has_more"
    }
}

// MARK: - VectorStoreFilesResponse
/// Represents a response containing files for a vector store.
struct VectorStoreFilesResponse: Codable {
    let data: [File]
    let firstId: String?
    let lastId: String?
    let hasMore: Bool

    private enum CodingKeys: String, CodingKey {
        case data, firstId = "first_id", lastId = "last_id", hasMore = "has_more"
    }
}

// MARK: - File
struct File: Identifiable, Codable {
    let id: String
    let name: String?
    let status: String
    let createdAt: Int
    let bytes: Int?
    let purpose: String?
    let mimeType: String?
    let objectType: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, status, bytes, purpose, mimeType, objectType
        case createdAt = "created_at"
    }
}

// Example JSON decoding
func decodeFile(from jsonData: Data) -> File? {
    let decoder = JSONDecoder()
    do {
        let file = try decoder.decode(File.self, from: jsonData)
        return file
    } catch {
        print("Failed to decode JSON: \(error.localizedDescription)")
        return nil
    }
}

// MARK: - FileBatch
struct FileBatch: Codable {
    let id: String
}

// MARK: - FileSearch
struct FileSearch: Codable {
    let maxNumResults: Int?

    func toFileSearchDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let maxNumResults = maxNumResults {
            dict["max_num_results"] = maxNumResults
        }
        return dict
    }

}
func handleUploadResponse(data: Data) -> Result<String, Error> {
    do {
        // Log the raw response data for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Upload Response JSON: \(jsonString)")
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        if let error = uploadResponse.error {
            // Log the error message from the response
            print("Upload Error: \(error.message)")
            return .failure(OpenAIServiceError.custom(error.message))
        }
        if let fileId = uploadResponse.fileId {
            return .success(fileId)
        } else {
            // Log a specific error message if the file ID is not found
            let errorMessage = "File ID not found in the response."
            print(errorMessage)
            return .failure(OpenAIServiceError.custom(errorMessage))
        }
    } catch {
        // Log the decoding error
        print("Decoding Error: \(error.localizedDescription)")
        return .failure(error)
    }
}



