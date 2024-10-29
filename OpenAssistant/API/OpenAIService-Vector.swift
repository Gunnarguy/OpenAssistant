import Foundation
import Combine

extension OpenAIService {
    
    // MARK: - Private Helper Methods
    
    private func createRequest(endpoint: String, method: String = "GET", body: [String: Any]? = nil) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        addCommonHeaders(to: &request)
        
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                print("Error serializing JSON: \(error)")
                return nil
            }
        }
        
        return request
    }
    
    func addCommonHeaders(to request: inout URLRequest) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    private func handleURLSessionDataTask<T: Decodable>(request: URLRequest, completion: @escaping (Result<T, Error>) -> Void) {
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let statusCode = httpResponse.statusCode
                let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                completion(.failure(NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorDescription])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decodedResponse))
            } catch {
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
    
    func uploadFile(fileData: Data, fileName: String) -> Future<String, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(OpenAIServiceError.custom("Self is nil")))
                return
            }
            
            let endpoint = "vector_stores/files"
            guard let request = self.createRequest(endpoint: endpoint, method: "POST", body: ["file": fileData, "fileName": fileName]) else {
                promise(.failure(OpenAIServiceError.custom("Failed to create request")))
                return
            }
            
            self.session.dataTask(with: request) { data, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let data = data else {
                    promise(.failure(OpenAIServiceError.noData))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let fileId = json?["id"] as? String {
                        promise(.success(fileId))
                    } else {
                        promise(.failure(OpenAIServiceError.custom("Invalid response structure")))
                    }
                } catch {
                    promise(.failure(error))
                }
            }.resume()
        }
    }
    
    
    // MARK: - Upload Files
    
    func uploadFiles(fileURLs: [URL], completion: @escaping (Result<[String], Error>) -> Void) {
        var uploadedFileIds: [String] = []
        var cancellables = Set<AnyCancellable>()
        let group = DispatchGroup()
        
        for fileURL in fileURLs {
            group.enter()
            guard let fileData = try? Data(contentsOf: fileURL) else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read file data"])))
                return
            }
            
            uploadFile(fileData: fileData, fileName: fileURL.lastPathComponent)
                .sink(receiveCompletion: { completionResult in
                    if case .failure(let error) = completionResult {
                        completion(.failure(error))
                    }
                    group.leave()
                }, receiveValue: { fileId in
                    uploadedFileIds.append(fileId)
                    group.leave()
                })
                .store(in: &cancellables)
        }
        
        group.notify(queue: .main) {
            completion(.success(uploadedFileIds))
        }
    }
    
    // MARK: - Batch Upload Files to Vector Store
    
    func createVectorStoreFileBatch(vectorStoreId: String, fileIds: [String], chunkingStrategy: [String: Any]? = nil, completion: @escaping (Result<VectorStoreFileBatch, Error>) -> Void) {
        let endpoint = "vector_stores/\(vectorStoreId)/file_batches"
        var body: [String: Any] = ["file_ids": fileIds]
        
        if let chunkingStrategy = chunkingStrategy {
            body["chunking_strategy"] = chunkingStrategy
        }
        
        guard let request = createRequest(endpoint: endpoint, method: "POST", body: body) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
            return
        }
        
        handleURLSessionDataTask(request: request, completion: completion)
    }

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



