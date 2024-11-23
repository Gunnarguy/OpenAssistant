import Foundation
import Combine
import SwiftUI

// Ensure the File type is imported or defined
struct File: Codable, Identifiable {
    let id: String
    let object: String?
    let name: String?
    let status: String
    let createdAt: Int
    let bytes: Int?
    let purpose: String?
    let mimeType: String?
    let objectType: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, status, bytes, purpose, mimeType, objectType, object
        case createdAt = "created_at"
    }
}

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

@MainActor
class VectorStoreManagerViewModel: BaseViewModel {
    @Published var vectorStores: [VectorStore] = []
    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false
    var assistant: Assistant? // Define assistant variable
    var vectorStore: VectorStore? // Define vectorStore variable
    private let baseURL = URL(string: "https://api.openai.com/v1")!
    private let session: URLSession
    var cancellables = Set<AnyCancellable>()

    override init() {
        self.session = URLSession.shared
        super.init()
        print("VectorStoreManagerViewModel initialized")
        initializeAndFetch()
    }

    private func initializeAndFetch() {
        fetchVectorStores()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    private func configureRequest(_ request: inout URLRequest, httpMethod: String) {
        request.httpMethod = httpMethod
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
    }

    private func addCommonHeaders(to request: inout URLRequest) {
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
    }

    private func createRequest(endpoint: String, method: String, body: [String: Any]? = nil) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            print("Invalid URL for endpoint: \(endpoint)")
            return nil
        }
        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: method)
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                print("Failed to serialize request body: \(error.localizedDescription)")
                return nil
            }
        }
        return request
    }

    func createVectorStore(name: String) -> AnyPublisher<String, Error> {
        guard let openAIService = openAIService else {
            return Fail(error: VectorStoreError.serviceNotInitialized).eraseToAnyPublisher()
        }
        return openAIService.createVectorStore(name: name)
            .eraseToAnyPublisher()
    }


    // MARK: - Vector Store Management
    func createAndAttachVectorStore() -> AnyPublisher<Void, Error> {
        Future<Void, Error> { promise in
            Task {
                do {
                    try await self.createAndAttachVectorStore()
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func createVectorStore(name: String) async throws -> String {
        guard let request = createRequest(endpoint: "vector_stores", method: "POST", body: ["name": name]) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let vectorStoreId = json?["id"] as? String else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Vector Store ID not found"])
        }

        return vectorStoreId
    }

    

    private func fetchAssistant(assistantId: String) -> AnyPublisher<Assistant, Error> {
        guard let url = URL(string: "\(baseURL)/assistants/\(assistantId)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "GET")

        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: Assistant.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func attachVectorStoreToAssistant(assistantId: String, vectorStoreId: String) async throws {
        guard let request = createRequest(endpoint: "assistants/\(assistantId)/tools", method: "POST", body: [
            "tools": [
                [
                    "type": "file_search",
                    "resources": [
                        "vector_store_ids": [vectorStoreId]
                    ]
                ]
            ]
        ]) else {
            throw URLError(.badURL)
        }

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    private func updateAssistantVectorStore(assistantId: String) {
        fetchAssistant(assistantId: assistantId)
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("Failed to refresh assistant: \(error.localizedDescription)")
                }
            }, receiveValue: { updatedAssistant in
                self.assistant = updatedAssistant
                print("Updated assistant's vector store: \(updatedAssistant.tool_resources?.fileSearch?.vectorStoreIds ?? [])")
            })
            .store(in: &cancellables)
    }
    
    
    func fetchVectorStore(id: String) -> AnyPublisher<VectorStore, Error> {
        guard let url = URL(string: "\(baseURL)/vector_stores/\(id)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "GET")

        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> VectorStore in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return try JSONDecoder().decode(VectorStore.self, from: data)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func uploadFile(fileData: Data, fileName: String, vectorStoreId: String) async throws -> String {
        let fileUploadService = FileUploadService(apiKey: apiKey)
        do {
            let fileId = try await fileUploadService.uploadFile(fileData: fileData, fileName: fileName)
                .first()
                .tryMap { $0 }

                .async()
            print("Successfully uploaded \(fileName) with ID: \(fileId)")
            return fileId
        } catch {
            print("Upload failed for \(fileName): \(error.localizedDescription)")
            throw error
        }
    }
    
    

    func addFileToVectorStore(vectorStoreId: String, fileId: String) async throws {
        guard let request = createRequest(endpoint: "vector_stores/\(vectorStoreId)/files", method: "POST", body: [
            "file_ids": [fileId]
        ]) else {
            throw URLError(.badURL)
        }

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func updateVectorStore(vectorStoreId: String, parameters: [String: Any], completion: @escaping (Result<VectorStore, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/vector_stores/\(vectorStoreId)") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "POST")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                self.handleDataTaskResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }

    func fetchVectorStores() -> AnyPublisher<[VectorStore], Never> {
        guard let openAIService = openAIService else {
            return Just([]).eraseToAnyPublisher()
        }
        return openAIService.fetchVectorStores()
            .receive(on: DispatchQueue.main)
            .catch { [weak self] error -> Just<[VectorStore]> in
                self?.handleError(IdentifiableError(message: error.localizedDescription))
                return Just([])
            }
            .handleEvents(receiveOutput: { [weak self] vectorStores in
                print("Received vector stores: \(vectorStores)")
                self?.vectorStores = vectorStores
            })
            .eraseToAnyPublisher()
    }

    func listVectorStores() -> AnyPublisher<[VectorStore], Error> {
        guard let url = URL(string: "\(baseURL)/vector_stores") else {
            return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "GET")

        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: [VectorStore].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func getVectorStore(vectorStoreId: String) -> AnyPublisher<VectorStore, Error> {
        guard let url = URL(string: "\(baseURL)/vector_stores/\(vectorStoreId)") else {
            return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "GET")

        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: VectorStore.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func fetchFiles(for vectorStore: VectorStore) -> AnyPublisher<[VectorStoreFile], Error> {
        guard let openAIService = openAIService else {
            handleError(.serviceNotInitialized)
            return Fail(error: VectorStoreError.serviceNotInitialized).eraseToAnyPublisher()
        }

        return openAIService.fetchFiles(for: vectorStore.id)
            .map { files -> [VectorStoreFile] in
                files.map { file in
                    VectorStoreFile(
                        id: file.id,
                        object: file.object ?? "file",
                        usageBytes: file.bytes ?? 0,
                        createdAt: file.createdAt,
                        vectorStoreId: vectorStore.id,
                        status: file.status,
                        lastError: nil,
                        chunkingStrategy: nil
                    )
                }
            }
            .receive(on: DispatchQueue.main)
            .handleEvents(
                receiveOutput: { [weak self] files in
                    self?.updateVectorStoreFiles(vectorStore: vectorStore, files: files)
                },
                receiveCompletion: { [weak self] completion in
                    self?.handleFetchFilesCompletion(completion)
                }
            )
            .eraseToAnyPublisher()
    }

    func getFileBatch(vectorStoreId: String, batchId: String) -> AnyPublisher<VectorStoreFileBatch, Error> {
        guard let url = URL(string: "\(baseURL)/vector_stores/\(vectorStoreId)/file_batches/\(batchId)") else {
            return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "GET")

        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: VectorStoreFileBatch.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func listFilesInFileBatch(vectorStoreId: String, batchId: String) -> AnyPublisher<[File], Error> {
        guard let url = URL(string: "\(baseURL)/vector_stores/\(vectorStoreId)/file_batches/\(batchId)/files") else {
            return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "GET")

        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: [File].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func deleteFileFromVectorStore(vectorStoreId: String, fileId: String) -> Future<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else { return }
            let endpoint = "vector_stores/\(vectorStoreId)/files/\(fileId)"
            // Use the HTTPMethod enum instead of a string
            guard let request = self.openAIService?.makeRequest(endpoint: endpoint, httpMethod: .delete) else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Request"])))
                return
            }
            self.openAIService?.session.dataTask(with: request) { _, _, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                promise(.success(()))
            }.resume()
        }
    }

    func deleteVectorStore(vectorStoreId: String) {
        guard let openAIService = openAIService else {
            handleError(.serviceNotInitialized)
            return
        }
        openAIService.deleteVectorStore(vectorStoreId: vectorStoreId)
            .sink(receiveCompletion: { [weak self] completion in
                self?.handleDeleteCompletion(completion, vectorStoreId: vectorStoreId)
            }, receiveValue: { _ in
                print("Vector store deleted successfully.")
            })
            .store(in: &cancellables)
    }

    func updateVectorStoreFiles(vectorStore: VectorStore, files: [VectorStoreFile]) {
        guard let index = vectorStores.firstIndex(where: { $0.id == vectorStore.id }) else {
            print("VectorStore not found")
            return
        }
        vectorStores[index].files = files

        let vectorStoreFiles = files.map { file in
            VectorStoreFile(
                id: file.id,
                object: "default_object",
                usageBytes: 0,
                createdAt: file.createdAt,
                vectorStoreId: vectorStore.id,
                status: "default_status",
                lastError: nil,
                chunkingStrategy: nil
            )
        }
        vectorStores[index].files = vectorStoreFiles
    }

    func getFileInVectorStore(vectorStoreId: String, fileId: String) -> AnyPublisher<File, Error> {
        guard let url = URL(string: "\(baseURL)/vector_stores/\(vectorStoreId)/files/\(fileId)") else {
            return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "GET")

        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: File.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    private func vectorStoreIndex(for vectorStore: VectorStore) -> Int? {
        return vectorStores.firstIndex(where: { $0.id == vectorStore.id })
    }

    private func handleError(_ error: VectorStoreError) {
        DispatchQueue.main.async {
            self.errorMessage = IdentifiableError(message: error.localizedDescription)
        }
    }

    private func handleFetchCompletion(_ completion: Subscribers.Completion<Never>) {
        if case .failure(let error) = completion {
            print("Fetch failed with error: \(error)")
        } else {
            print("Fetch completed successfully")
        }
    }

    private func handleFetchFilesCompletion(_ completion: Subscribers.Completion<Error>) {
        if case .failure(let error) = completion {
            handleError(.fetchFailed(error.localizedDescription))
        }
    }

    private func handleDeleteCompletion(_ completion: Subscribers.Completion<Error>, vectorStoreId: String) {
        if case .failure(let error) = completion {
            handleError(.fetchFailed(error.localizedDescription))
        } else {
            vectorStores.removeAll { $0.id == vectorStoreId }
        }
    }

    private func handleDataTaskResponse<T: Decodable>(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<T, Error>) -> Void) {
        if let error = error {
            completion(.failure(error))
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
    }

    private func handleDataTaskResponse<T: Decodable>(data: Data?, response: URLResponse?, error: Error?, promise: @escaping (Result<T, Error>) -> Void) {
        if let error = error {
            promise(.failure(error))
            return
        }
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
            promise(.failure(NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorDescription])))
            return
        }
        guard let data = data else {
            promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            return
        }
        do {
            let response = try JSONDecoder().decode(T.self, from: data)
            promise(.success(response))
        } catch {
            promise(.failure(error))
        }
    }
}

extension Future where Failure == Error {
    func asyncResult() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            _ = self.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                },
                receiveValue: { value in
                    continuation.resume(returning: value)
                }
            )
            // Store the cancellable if needed to retain the subscription
        }
    }
}
extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = self.sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    }
                    cancellable = nil
                },
                receiveValue: { value in
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                    cancellable = nil
                }
            )
        }
    }
}
