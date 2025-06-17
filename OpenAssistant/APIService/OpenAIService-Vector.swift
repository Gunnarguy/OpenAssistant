import Combine
import Foundation

extension OpenAIService {

    // MARK: - Private Helper Methods

    /// Creates a URLRequest with dynamic Content-Type handling for JSON and multipart requests
    func createRequest(
        endpoint: String, method: HTTPMethod = .get, body: [String: Any]? = nil,
        contentType: ContentType = .json
    ) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            print("Invalid URL for endpoint: \(endpoint)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        addCommonHeaders(to: &request)

        // Set the Content-Type header from enum rawValue.
        request.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")

        // Serialize JSON: check against .json instead of the string "application/json"
        if let body = body, contentType == .json {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
                request.httpBody = jsonData
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("Request Body JSON: \(jsonString)")
                }
            } catch {
                print("Error serializing JSON: \(error)")
                return nil
            }
        }

        print("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Request URL: \(request.url?.absoluteString ?? "Unknown URL")")
        return request
    }

    /// Adds common headers required for OpenAI requests

    /// Executes a URLSession data task and handles decoding the response
    func handleURLSessionDataTask<T: Decodable>(
        request: URLRequest, completion: @escaping (Result<T, Error>) -> Void
    ) {
        session.dataTask(with: request) { data, response, error in
            self.handleDataTaskResponse(
                data: data, response: response, error: error, completion: completion)
        }.resume()
    }

    // MARK: - Request Configuration

    func createVectorStore(name: String) -> AnyPublisher<String, Error> {
        guard let url = URL(string: "\(baseURL)vector_stores") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let body: [String: Any] = ["name": name]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }

        // Use the new retry mechanism by adapting it for Combine publishers
        return Future<String, Error> { promise in
            self.performDataTaskWithRetry(request) { data, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode)
                else {
                    // Attempt to decode error message from OpenAI if available
                    if let data = data,
                        let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                    {
                        promise(
                            .failure(
                                NSError(
                                    domain: "OpenAPIError",
                                    code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                    userInfo: [NSLocalizedDescriptionKey: apiError.error.message])))
                    } else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                        let errorDescription = HTTPURLResponse.localizedString(
                            forStatusCode: statusCode)
                        promise(
                            .failure(
                                NSError(
                                    domain: "NetworkError", code: statusCode,
                                    userInfo: [
                                        NSLocalizedDescriptionKey:
                                            "Invalid response: \(errorDescription)"
                                    ])))
                    }
                    return
                }
                guard let data = data else {
                    promise(
                        .failure(
                            NSError(
                                domain: "NetworkError", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    guard let vectorStoreId = json?["id"] as? String else {
                        promise(
                            .failure(
                                NSError(
                                    domain: "", code: -1,
                                    userInfo: [
                                        NSLocalizedDescriptionKey:
                                            "Vector Store ID not found in response"
                                    ])))
                        return
                    }
                    promise(.success(vectorStoreId))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    func createVectorStore(
        name: String, completion: @escaping (Result<VectorStore, OpenAIServiceError>) -> Void
    ) {
        let endpoint = "vector_stores"
        let body: [String: Any] = ["name": name]

        guard let request = createRequest(endpoint: endpoint, method: .post, body: body) else {
            completion(.failure(.invalidRequest))
            return
        }

        // Use the new retry mechanism
        performDataTaskWithRetry(request) { data, response, error in
            self.handleResponse(data, response, error) { result in
                if case .success(let store) = result {
                    NotificationCenter.default.post(name: .vectorStoreCreated, object: store.id)
                }
                completion(result)
            }
        }
    }

    // MARK: - Fetch Vector Stores

    func fetchVectorStores() -> Future<[VectorStore], Error> {
        return Future { promise in
            let endpoint = "vector_stores"

            guard let request = self.createRequest(endpoint: endpoint) else {
                promise(
                    .failure(
                        NSError(
                            domain: "", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
                return
            }

            // Use the new retry mechanism
            self.performDataTaskWithRetry(request) { data, response, error in
                self.handleDataTaskResponse(data: data, response: response, error: error) {
                    (result: Result<VectorStoreResponse, Error>) in
                    switch result {
                    case .success(let response):
                        promise(.success(response.data))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
            }
        }
    }

    // MARK: - Fetch Vector Store Details

    func fetchVectorStoreDetails(vectorStoreId: String) -> Future<VectorStore, Error> {
        return Future { promise in
            let endpoint = "vector_stores/\(vectorStoreId)"

            guard let request = self.createRequest(endpoint: endpoint) else {
                promise(
                    .failure(
                        NSError(
                            domain: "", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
                return
            }
            // Use the new retry mechanism
            self.performDataTaskWithRetry(request) { data, response, error in
                self.handleDataTaskResponse(
                    data: data, response: response, error: error, completion: promise)
            }
        }
    }

    // MARK: - Fetch Files

    func fetchFiles(for vectorStoreId: String) -> Future<[File], Error> {
        return Future { promise in
            let endpoint = "vector_stores/\(vectorStoreId)/files"

            guard let request = self.createRequest(endpoint: endpoint) else {
                promise(
                    .failure(
                        NSError(
                            domain: "", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
                return
            }
            // Use the new retry mechanism
            self.performDataTaskWithRetry(request) { data, response, error in
                self.handleDataTaskResponse(data: data, response: response, error: error) {
                    (result: Result<VectorStoreFilesResponse, Error>) in
                    switch result {
                    case .success(let response):
                        promise(.success(response.data))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
            }
        }
    }

    // MARK: - Retrieve File Batch

    func getFileBatch(vectorStoreId: String, batchId: String) -> AnyPublisher<
        VectorStoreFileBatch, Error
    > {
        guard
            let request = makeRequest(
                endpoint: "vector_stores/\(vectorStoreId)/file_batches/\(batchId)", httpMethod: .get
            )
        else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        // Use the new retry mechanism by adapting it for Combine publishers
        return Future<VectorStoreFileBatch, Error> { promise in
            self.performDataTaskWithRetry(request) { data, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode)
                else {
                    // Attempt to decode error message from OpenAI if available
                    if let data = data,
                        let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                    {
                        promise(
                            .failure(
                                NSError(
                                    domain: "OpenAPIError",
                                    code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                    userInfo: [NSLocalizedDescriptionKey: apiError.error.message])))
                    } else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                        let errorDescription = HTTPURLResponse.localizedString(
                            forStatusCode: statusCode)
                        promise(
                            .failure(
                                NSError(
                                    domain: "NetworkError", code: statusCode,
                                    userInfo: [
                                        NSLocalizedDescriptionKey:
                                            "Invalid response: \(errorDescription)"
                                    ])))
                    }
                    return
                }
                guard let data = data else {
                    promise(
                        .failure(
                            NSError(
                                domain: "NetworkError", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                do {
                    let decodedResponse = try JSONDecoder().decode(
                        VectorStoreFileBatch.self, from: data)
                    promise(.success(decodedResponse))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    // MARK: - List Files in File Batch

    func listFilesInFileBatch(vectorStoreId: String, batchId: String) -> AnyPublisher<[File], Error>
    {
        guard
            let request = makeRequest(
                endpoint: "vector_stores/\(vectorStoreId)/file_batches/\(batchId)/files",
                httpMethod: .get)
        else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        // Use the new retry mechanism by adapting it for Combine publishers
        return Future<[File], Error> { promise in
            self.performDataTaskWithRetry(request) { data, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode)
                else {
                    // Attempt to decode error message from OpenAI if available
                    if let data = data,
                        let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                    {
                        promise(
                            .failure(
                                NSError(
                                    domain: "OpenAPIError",
                                    code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                    userInfo: [NSLocalizedDescriptionKey: apiError.error.message])))
                    } else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                        let errorDescription = HTTPURLResponse.localizedString(
                            forStatusCode: statusCode)
                        promise(
                            .failure(
                                NSError(
                                    domain: "NetworkError", code: statusCode,
                                    userInfo: [
                                        NSLocalizedDescriptionKey:
                                            "Invalid response: \(errorDescription)"
                                    ])))
                    }
                    return
                }
                guard let data = data else {
                    promise(
                        .failure(
                            NSError(
                                domain: "NetworkError", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                do {
                    let decodedResponse = try JSONDecoder().decode([File].self, from: data)
                    promise(.success(decodedResponse))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    // MARK: - MIME Type Helper

    /// Returns the appropriate MIME type for a given file extension
    func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "c": return "text/x-c"
        case "cpp": return "text/x-c++"
        case "css": return "text/css"
        case "csv": return "text/csv"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "html": return "text/html"
        case "java": return "text/x-java"
        case "js": return "text/javascript"
        case "json": return "application/json"
        case "md": return "text/markdown"
        case "pdf": return "application/pdf"
        case "php": return "text/x-php"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "py": return "text/x-python"
        case "rb": return "text/x-ruby"
        case "tex": return "text/x-tex"
        case "ts": return "application/typescript"
        case "txt": return "text/plain"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "xml": return "text/xml"
        default: return "application/octet-stream"  // Fallback for unknown types
        }
    }

    // MARK: - Update Vector Store

    func modifyVectorStore(
        vectorStoreId: String, name: String? = nil, expiresAfter: [String: Any]? = nil,
        metadata: [String: String]? = nil, files: [[String: Any]]? = nil,
        completion: @escaping (Result<VectorStore, Error>) -> Void
    ) {
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

        guard let request = createRequest(endpoint: endpoint, method: .post, body: body) else {
            completion(
                .failure(
                    NSError(
                        domain: "", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
            return
        }
        // Use the new retry mechanism
        performDataTaskWithRetry(request) { data, response, error in
            self.handleDataTaskResponse(
                data: data, response: response, error: error, completion: completion)
        }
    }

    // MARK: - Delete Vector Store

    func deleteVectorStore(vectorStoreId: String) -> AnyPublisher<Void, Error> {
        let endpoint = "vector_stores/\(vectorStoreId)"

        guard let request = createRequest(endpoint: endpoint, method: .delete) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        // Use the new retry mechanism by adapting it for Combine publishers
        return Future<Void, Error> { promise in
            self.performDataTaskWithRetry(request) { data, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode == 200
                else {
                    // Attempt to decode error message from OpenAI if available
                    if let data = data,
                        let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                    {
                        promise(
                            .failure(
                                NSError(
                                    domain: "OpenAPIError",
                                    code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                    userInfo: [NSLocalizedDescriptionKey: apiError.error.message])))
                    } else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                        let errorDescription = HTTPURLResponse.localizedString(
                            forStatusCode: statusCode)
                        promise(
                            .failure(
                                NSError(
                                    domain: "NetworkError", code: statusCode,
                                    userInfo: [
                                        NSLocalizedDescriptionKey:
                                            "Invalid response: \(errorDescription)"
                                    ])))
                    }
                    return
                }
                guard let data = data else {
                    promise(
                        .failure(
                            NSError(
                                domain: "NetworkError", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                do {
                    let deleteResponse = try JSONDecoder().decode(DeleteResponse.self, from: data)
                    guard deleteResponse.deleted else {
                        promise(.failure(URLError(.cannotParseResponse)))
                        return
                    }
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    // MARK: - Delete File

    func deleteFile(fileID: String) -> AnyPublisher<Void, Error> {
        let endpoint = "files/\(fileID)"

        guard let request = createRequest(endpoint: endpoint, method: .delete) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        // Use the new retry mechanism by adapting it for Combine publishers
        return Future<Void, Error> { promise in
            self.performDataTaskWithRetry(request) { data, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode)
                else {  // Assuming 200-299 is success for delete file
                    // Attempt to decode error message from OpenAI if available
                    if let data = data,
                        let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                    {
                        promise(
                            .failure(
                                NSError(
                                    domain: "OpenAPIError",
                                    code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                    userInfo: [NSLocalizedDescriptionKey: apiError.error.message])))
                    } else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                        let errorDescription = HTTPURLResponse.localizedString(
                            forStatusCode: statusCode)
                        promise(
                            .failure(
                                NSError(
                                    domain: "NetworkError", code: statusCode,
                                    userInfo: [
                                        NSLocalizedDescriptionKey:
                                            "Invalid response: \(errorDescription)"
                                    ])))
                    }
                    return
                }
                promise(.success(()))  // Successful deletion, no specific data expected beyond status code
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

// MARK: - VectorStore
/// Represents a vector store with associated files and metadata.
struct VectorStore: Identifiable, Codable, Equatable {
    let id: String
    let name: String?
    let description: String?
    let status: String?
    let usageBytes: Int?
    let createdAt: Int
    let fileCounts: FileCounts
    let metadata: [String: String]?
    let expiresAfter: ExpiresAfterType?
    let expiresAt: Int?
    let lastActiveAt: Int?
    var files: [VectorStoreFile]?  // Mutable to allow updates
    private enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case usageBytes = "bytes"
        case createdAt = "created_at"
        case fileCounts = "file_counts"
        case metadata
        case expiresAfter = "expires_after"
        case expiresAt = "expires_at"
        case lastActiveAt = "last_active_at"
        case files
    }
    static func == (lhs: VectorStore, rhs: VectorStore) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - LastError
/// Represents the last error object returned by the API.
struct LastError: Codable {
    let code: String
    let message: String
}

// MARK: - VectorStoreFile
struct VectorStoreFile: Codable, Identifiable {
    let id: String
    let object: String
    let usageBytes: Int
    let createdAt: Int
    let vectorStoreId: String
    let status: String
    let lastError: LastError?  // Changed from String? to LastError?
    let chunkingStrategy: ChunkingStrategy?

    private enum CodingKeys: String, CodingKey {
        case id, object
        case usageBytes = "usage_bytes"
        case createdAt = "created_at"
        case vectorStoreId = "vector_store_id"
        case status
        case lastError = "last_error"
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
        case id, object
        case createdAt = "created_at"
        case vectorStoreId = "vector_store_id"
        case status
        case fileCounts = "file_counts"
    }
}

// MARK: - ChunkingStrategy
struct ChunkingStrategy: Codable {
    let type: String
    let staticStrategy: StaticStrategy?

    private enum CodingKeys: String, CodingKey {
        case type
        case staticStrategy = "static"
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
            "chunk_overlap_tokens": chunkOverlapTokens,
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
        case inProgress = "in_progress"
        case completed, failed, cancelled, total
    }
}

// MARK: - VectorStoreResponse
// VectorStoreResponse.swift
struct VectorStoreResponse: Codable {
    let data: [VectorStore]
    let firstId: String?
    let lastId: String?
    let hasMore: Bool

    private enum CodingKeys: String, CodingKey {
        case data
        case firstId = "first_id"
        case lastId = "last_id"
        case hasMore = "has_more"
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
        case data
        case firstId = "first_id"
        case lastId = "last_id"
        case hasMore = "has_more"
    }
}

// MARK: - File
struct File: Identifiable, Codable {
    let id: String
    let object: String?
    let name: String?
    let status: String
    let createdAt: Int
    let bytes: Int?
    let purpose: String?
    let mimeType: String?
    let objectType: String?
    let lastError: LastError?  // Changed from String? to LastError?
    let chunkingStrategy: ChunkingStrategy?

    private enum CodingKeys: String, CodingKey {
        case id, name, status, bytes, purpose, mimeType, objectType, object
        case lastError = "last_error"
        case chunkingStrategy = "chunking_strategy"
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
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Upload Response JSON: \(jsonString)")
        }

        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        if let error = uploadResponse.error {
            print("Upload Error: \(error.message)")
            return .failure(OpenAIServiceError.custom(error.message))
        }

        if let fileId = uploadResponse.fileId {
            return .success(fileId)
        } else {
            let errorMessage = "File ID not found in the response."
            print(errorMessage)
            return .failure(OpenAIServiceError.custom(errorMessage))
        }
    } catch {
        print("Decoding Error: \(error.localizedDescription)")
        return .failure(error)
    }
}
