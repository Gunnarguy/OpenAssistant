import Foundation
import Combine
import SwiftUI

@MainActor
class VectorStoreManagerViewModel: BaseViewModel {
    @Published var vectorStores: [VectorStore] = []
    private let baseURL = URL(string: "https://api.openai.com/v1")!
    private let session: URLSession
    var cancellables = Set<AnyCancellable>() // Change access level to internal
    @Published var alertMessage: String?
    @Published var showAlert: Bool = false

    override init() {
        self.session = URLSession.shared
        super.init()
        print("VectorStoreManagerViewModel initialized")
        initializeAndFetch()
    }

    private func configureRequest(_ request: inout URLRequest, httpMethod: String) {
        request.httpMethod = httpMethod
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
    }

    func initializeAndFetch() {
        fetchVectorStores()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("Successfully fetched vector stores.")
                case .failure(let error):
                    print("Error fetching vector stores: \(error.localizedDescription)")
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }, receiveValue: { [weak self] stores in
                self?.vectorStores = stores
            })
            .store(in: &cancellables)
    }

    func createRequest(endpoint: String, method: String, body: [String: Any]? = nil) -> URLRequest? {
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
        guard let url = URL(string: "\(baseURL)/vector_stores") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "POST")

        let json: [String: Any] = ["name": name]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else {
            return Fail(error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize JSON data."]))
                .eraseToAnyPublisher()
        }
        request.httpBody = jsonData

        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> String in
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                    throw NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorDescription])
                }
                guard let responseJSON = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let vectorStoreId = responseJSON["id"] as? String else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse vector store ID from response."])
                }
                return vectorStoreId
            }
            .eraseToAnyPublisher()
    }

    func fetchAssistants(for vectorStore: VectorStore) -> AnyPublisher<[Assistant], Error> {
        let url = baseURL.appendingPathComponent("vector_stores/\(vectorStore.id)/assistants")
        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "GET")

        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> [Assistant] in
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return try JSONDecoder().decode([Assistant].self, from: data)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
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
            print("Successfully uploaded \(fileName) with ID: \(fileId)")
            return fileId
        } catch {
            print("Upload failed for \(fileName): \(error.localizedDescription)")
            throw error
        }
    }

    func addFileToVectorStore(vectorStoreId: String, fileId: String) async throws {
        let endpoint = "vector_stores/\(vectorStoreId)/file_batches"
        let body: [String: Any] = ["file_ids": [fileId]]

        guard let request = createRequest(endpoint: endpoint, method: "POST", body: body) else {
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

    func fetchVectorStores() -> AnyPublisher<[VectorStore], Error> {
        let endpoint = "vector_stores"
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "GET")
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> [VectorStore] in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let vectorStoreResponse = try JSONDecoder().decode(VectorStoreResponse.self, from: data)
                return vectorStoreResponse.data
            }
            .receive(on: DispatchQueue.main)
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

    func vectorStoreIndex(for vectorStore: VectorStore) -> Int? {
        return vectorStores.firstIndex(where: { $0.id == vectorStore.id })
    }

    func handleError(_ error: VectorStoreError) {
        DispatchQueue.main.async {
            self.errorMessage = IdentifiableError(message: error.localizedDescription)
        }
    }

    func handleFetchCompletion(_ completion: Subscribers.Completion<Never>) {
        if case .failure(let error) = completion {
            print("Fetch failed with error: \(error)")
        } else {
            print("Fetch completed successfully")
        }
    }

    func handleFetchFilesCompletion(_ completion: Subscribers.Completion<Error>) {
        if case .failure(let error) = completion {
            handleError(.fetchFailed(error.localizedDescription))
        }
    }

    func handleDeleteCompletion(_ completion: Subscribers.Completion<Error>, vectorStoreId: String) {
        if case .failure(let error) = completion {
            handleError(.fetchFailed(error.localizedDescription))
        } else {
            vectorStores.removeAll { $0.id == vectorStoreId }
        }
    }

    func handleDataTaskResponse<T: Decodable>(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<T, Error>) -> Void) {
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

    // Add Vector Store ID to Assistant
    func addVectorStoreId(to assistant: inout Assistant, vectorStoreId: String) {
        if assistant.tool_resources == nil {
            assistant.tool_resources = ToolResources(fileSearch: FileSearchResources(vectorStoreIds: [vectorStoreId]))
        } else {
            if assistant.tool_resources?.fileSearch == nil {
                assistant.tool_resources?.fileSearch = FileSearchResources(vectorStoreIds: [vectorStoreId])
            } else {
                assistant.tool_resources?.fileSearch?.vectorStoreIds?.append(vectorStoreId)
            }
        }
    }

    // Remove Vector Store ID from Assistant
    func removeVectorStoreId(from assistant: inout Assistant, vectorStoreId: String) {
        assistant.tool_resources?.fileSearch?.vectorStoreIds?.removeAll { $0 == vectorStoreId }
    }

    func showNotification(message: String) {
        alertMessage = message
        showAlert = true
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
