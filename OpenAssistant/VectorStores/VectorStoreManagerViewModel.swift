import Foundation
import Combine
import SwiftUI

@MainActor
class VectorStoreManagerViewModel: BaseViewModel {
    @Published var vectorStores: [VectorStore] = []

    override init() {
        super.init()
        print("VectorStoreManagerViewModel initialized")
        initializeAndFetch()
    }

    private func initializeAndFetch() {
        fetchVectorStores()
            .sink(receiveCompletion: handleFetchCompletion, receiveValue: { _ in })
            .store(in: &cancellables)
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

    func fetchFiles(for vectorStore: VectorStore) {
        guard let openAIService = openAIService else {
            handleError(.serviceNotInitialized)
            return
        }
        openAIService.fetchFiles(for: vectorStore.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.handleFetchFilesCompletion(completion)
            }, receiveValue: { [weak self] files in
                self?.updateVectorStoreFiles(vectorStore: vectorStore, files: files)
            })
            .store(in: &cancellables)
    }

    func createFileBatch(vectorStoreId: String, fileIds: [String], chunkingStrategy: ChunkingStrategy?, completion: @escaping (Result<VectorStoreFileBatch, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/vector_stores/\(vectorStoreId)/file_batches") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "POST")
        
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

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                self?.handleDataTaskResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }

    func addFileToVectorStore(vectorStoreId: String, fileData: Data, fileName: String) -> Future<String, Error> {
        return Future { [weak self] promise in
            guard let self = self else { return }
            guard let url = URL(string: "https://api.openai.com/v1/vector_stores/\(vectorStoreId)/files") else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }

            var request = URLRequest(url: url)
            self.configureRequest(&request, httpMethod: "POST")

            let file: [String: Any] = [
                "file_name": fileName,
                "file_data": fileData.base64EncodedString()
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: file)

            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                Task { @MainActor in
                    self?.handleDataTaskResponse(data: data, response: response, error: error, promise: promise)
                }
            }.resume()
        }
    }

    func deleteFileFromVectorStore(vectorStoreId: String, fileId: String) -> Future<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else { return }
            let endpoint = "vector_stores/\(vectorStoreId)/files/\(fileId)"
            guard let request = self.openAIService?.makeRequest(endpoint: endpoint, httpMethod: "DELETE") else {
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

    private func updateVectorStoreFiles(vectorStore: VectorStore, files: [File]) {
        guard let index = vectorStoreIndex(for: vectorStore) else {
            print("VectorStore not found")
            return
        }
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

    private func configureRequest(_ request: inout URLRequest, httpMethod: String) {
        request.httpMethod = httpMethod
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
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
            let response = try JSONDecoder().decode(T.self, from: data)
            completion(.success(response))
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

extension OpenAIService {
    func makeRequest(endpoint: String, httpMethod: String) -> URLRequest? {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        return request
    }
}

extension ChunkingStrategy {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let staticStrategy = staticStrategy {
            dict["static"] = [
                "max_chunk_size_tokens": staticStrategy.maxChunkSizeTokens,
                "chunk_overlap_tokens": staticStrategy.chunkOverlapTokens
            ]
        }
        return dict
    }
}
