import Foundation
import Combine
import SwiftUI

class VectorStoreManagerViewModel: ObservableObject {
    @Published var vectorStores: [VectorStore] = []
    @Published var errorMessage: IdentifiableError?

    var openAIService: OpenAIService?
    var cancellables = Set<AnyCancellable>()

    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""

    init() {
        initializeOpenAIService()
        fetchVectorStores()
    }

    private func initializeOpenAIService() {
        guard !apiKey.isEmpty else {
            handleError(.missingAPIKey)
            return
        }
        openAIService = OpenAIService(apiKey: apiKey)
    }

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
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("Failed to fetch files: \(error)")
                    self.handleError(.fetchFailed(error.localizedDescription))
                }
            }, receiveValue: { [weak self] files in
                guard let self = self else { return }
                guard let index = self.vectorStores.firstIndex(where: { $0.id == vectorStore.id }) else {
                    print("VectorStore not found")
                    return
                }
                // Map [File] to [VectorStoreFile] with available properties
                let vectorStoreFiles = files.map { file in
                    VectorStoreFile(
                        id: file.id,
                        object: "default_object", // Provide a default or handle appropriately
                        usageBytes: 0, // Provide a default or handle appropriately
                        createdAt: file.createdAt,
                        vectorStoreId: vectorStore.id,
                        status: "default_status", // Provide a default or handle appropriately
                        lastError: nil, // Provide a default or handle appropriately
                        chunkingStrategy: nil // Provide a default or handle appropriately
                    )
                }
                self.vectorStores[index].files = vectorStoreFiles
            })
            .store(in: &cancellables)
    }

    private func handleError(_ error: VectorStoreError) {
        DispatchQueue.main.async {
            self.errorMessage = IdentifiableError(message: error.localizedDescription)
        }
    }

    // Function to create a new vector store
    func createVectorStore(name: String, files: [[String: Any]], completion: @escaping (Result<VectorStore, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/vector_stores") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Ensure the body includes the vector store name and files in the correct format
        let body: [String: Any] = [
            "name": name,
            "files": files
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
                let response = try JSONDecoder().decode(VectorStore.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Method to create a file batch in a vector store
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
    
    // Method to add a file to a vector store
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
    
    func createFileBatch(vectorStoreId: String, fileIds: [String]) {
        guard let openAIService = openAIService else {
            handleError(.serviceNotInitialized)
            return
        }

        openAIService.createVectorStoreFileBatch(vectorStoreId: vectorStoreId, fileIds: fileIds)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("File batch successfully created.")
                case .failure(let error):
                    print("Error: \(error.localizedDescription)")
                }
            }, receiveValue: { batch in
                print("Batch created with ID: \(batch.id)")
            })
            .store(in: &cancellables)
    }

    func deleteFileFromVectorStore(vectorStoreId: String, fileId: String) -> Future<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else { return }
            let endpoint = "vector_stores/\(vectorStoreId)/files/\(fileId)"
            let request = self.openAIService?.makeRequest(endpoint: endpoint, httpMethod: "DELETE")

            guard let request = request else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Request"])))
                return
            }

            self.openAIService?.session.dataTask(with: request) { _, response, error in
                self.openAIService?.handleDeleteResponse(nil, response, error) { result in
                    switch result {
                    case .success:
                        promise(.success(()))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
            }.resume()
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
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta") // Add this line
        return request
    }
}
