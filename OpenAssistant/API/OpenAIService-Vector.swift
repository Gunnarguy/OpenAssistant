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
    
    private func addCommonHeaders(to request: inout URLRequest) {
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
    
    func createVectorStore(name: String, files: [[String: Any]], completion: @escaping (Result<VectorStore, Error>) -> Void) {
        let endpoint = "vector_stores"
        let body: [String: Any] = [
            "name": name,
            "files": files
        ]
        
        guard let request = createRequest(endpoint: endpoint, method: "POST", body: body) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
            return
        }
        
        handleURLSessionDataTask(request: request, completion: completion)
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
    func batchUploadFilesToVectorStore(vectorStoreId: String, fileURLs: [URL], completion: @escaping (Result<Void, Error>) -> Void) {
        uploadFiles(fileURLs: fileURLs) { [self] result in
            switch result {
            case .success(let fileIds):
                // Use the batch method to add files to the vector store
                var request = URLRequest(url: URL(string: "https://api.openai.com/v1/vector_stores/\(vectorStoreId)/file_batches")!)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body: [String: Any] = ["file_ids": fileIds]
                let bodyData = try? JSONSerialization.data(withJSONObject: body)
                request.httpBody = bodyData
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    completion(.success(()))
                }
                task.resume()
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Update Vector Store
    
    func updateVectorStore(vectorStoreId: String, name: String? = nil, files: [[String: Any]]? = nil, completion: @escaping (Result<VectorStore, Error>) -> Void) {
        let endpoint = "vector_stores/\(vectorStoreId)"
        var body: [String: Any] = [:]
        
        if let name = name {
            body["name"] = name
        }
        
        if let files = files {
            body["files"] = files
        }
        
        guard let request = createRequest(endpoint: endpoint, method: "PUT", body: body) else {
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
