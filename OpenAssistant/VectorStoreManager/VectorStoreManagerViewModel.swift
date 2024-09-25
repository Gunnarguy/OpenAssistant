import Foundation
import Combine
import SwiftUI

@MainActor
class VectorStoreManagerViewModel: ObservableObject {
    @Published var vectorStores: [VectorStore] = []
    @Published var errorMessage: IdentifiableError?
    
    private var openAIService: OpenAIService?
    var cancellables = Set<AnyCancellable>()
    
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""
    
    init() {
        initializeOpenAIService()
        fetchVectorStores()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    self.handleError(.fetchFailed(error.localizedDescription))
                }
            }, receiveValue: { vectorStores in
                self.vectorStores = vectorStores
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Initialization
    
    private func initializeOpenAIService() {
        guard !apiKey.isEmpty else {
            handleError(.serviceNotInitialized)
            return
        }
        openAIService = OpenAIService(apiKey: apiKey)
    }
    
    // MARK: - Data Fetching
    
    func fetchVectorStores() -> AnyPublisher<[VectorStore], Never> {
        guard let openAIService = openAIService else {
            handleError(.serviceNotInitialized)
            return Just([]).eraseToAnyPublisher()
        }
        return openAIService.fetchVectorStores()
            .receive(on: DispatchQueue.main)
            .catch { [weak self] error -> Just<[VectorStore]> in
                self?.handleError(.fetchFailed(error.localizedDescription))
                return Just([])
            }
            .handleEvents(receiveOutput: { [weak self] vectorStores in
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
                if case let .failure(error) = completion {
                    self?.handleError(.fetchFailed(error.localizedDescription))
                }
            }, receiveValue: { [weak self] files in
                self?.updateVectorStoreFiles(vectorStore: vectorStore, files: files)
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Vector Store Management
    
    func createFileBatch(vectorStoreId: String, fileIds: [String], completion: @escaping (Result<VectorStoreFileBatch, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/vector_stores/\(vectorStoreId)/file_batches") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        
        let body: [String: Any] = [
            "file_ids": fileIds
            // Optionally add "chunking_strategy" if needed
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
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
                let response = try JSONDecoder().decode(VectorStoreFileBatch.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func addFileToVectorStore(vectorStoreId: String, fileData: Data, fileName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/vector_stores/\(vectorStoreId)/files") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "file_name": fileName,
            "file_data": fileData.base64EncodedString()
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }.resume()
    }
    
func deleteFileFromVectorStore(vectorStoreId: String, fileId: String) -> Future<Void, Error> {
    return Future { [weak self] promise in
        guard let self = self else { return }
        let endpoint = "vector_stores/\(vectorStoreId)/files/\(fileId)"
        guard let request = self.openAIService?.makeRequest(endpoint: endpoint, httpMethod: "DELETE") else {
            promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Request"])))
            return
        }
        self.openAIService?.session.dataTask(with: request) { _, response, error in
            Task { @MainActor in
                self.openAIService?.handleDeleteResponse(nil, response, error) { result in
                    switch result {
                    case .success:
                        promise(.success(()))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
            }
        }.resume()
    }
}

    
    func deleteVectorStore(vectorStoreId: String) {
        guard let openAIService = openAIService else {
            handleError(.serviceNotInitialized)
            return
        }
        openAIService.deleteVectorStore(vectorStoreId: vectorStoreId)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    self.vectorStores.removeAll { $0.id == vectorStoreId }
                case .failure(let error):
                    self.handleError(.fetchFailed(error.localizedDescription))
                }
            }, receiveValue: { _ in
                print("Vector store deleted successfully.")
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
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
}

// MARK: - Helper Method for Requests

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
