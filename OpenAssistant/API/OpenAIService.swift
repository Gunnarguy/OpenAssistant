import Foundation
import Combine
import SwiftUI

class OpenAIService {
    let apiKey: String
    let baseURL = URL(string: "https://api.openai.com/v1/")!
    let session: URLSession
    
    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    private enum HTTPHeaderField: String {
        case authorization = "Authorization"
        case contentType = "Content-Type"
        case openAIBeta = "OpenAI-Beta"
    }

    private enum ContentType: String {
        case json = "application/json"
    }

    // MARK: - Request Creation

    func makeRequest(endpoint: String, httpMethod: String = "GET", body: [String: Any]? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = httpMethod
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: HTTPHeaderField.authorization.rawValue)
        request.addValue(ContentType.json.rawValue, forHTTPHeaderField: HTTPHeaderField.contentType.rawValue)
        request.addValue("assistants=v2", forHTTPHeaderField: HTTPHeaderField.openAIBeta.rawValue)

        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                print("Error serializing JSON body: \(error.localizedDescription)")
            }
        }

        return request
    }

    private func handleResponse<T: Decodable>(_ data: Data?, _ response: URLResponse?, _ error: Error?, completion: @escaping (Result<T, OpenAIServiceError>) -> Void) {
        if let error = error {
            logError("Network error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(.networkError(error)))
            }
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            DispatchQueue.main.async {
                completion(.failure(.unknownError))
            }
            return
        }

        // Log the status code and response data
        logInfo("HTTP Status Code: \(httpResponse.statusCode)")
        if let data = data {
            logResponseData(data)
        }

        if !(200...299).contains(httpResponse.statusCode) {
            switch httpResponse.statusCode {
            case 429:
                let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? Int ?? 1
                DispatchQueue.main.async {
                    completion(.failure(.rateLimitExceeded(retryAfter)))
                }
            case 500:
                DispatchQueue.main.async {
                    completion(.failure(.internalServerError))
                }
            default:
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse(httpResponse)))
                }
            }
            return
        }

        guard let data = data else {
            logError("No data received")
            DispatchQueue.main.async {
                completion(.failure(.noData))
            }
            return
        }

        do {
            let decodedResponse = try JSONDecoder().decode(T.self, from: data)
            DispatchQueue.main.async {
                completion(.success(decodedResponse))
            }
        } catch {
            logError("Decoding error: \(error.localizedDescription)")
            logError("Response data: \(String(data: data, encoding: .utf8) ?? "N/A")")
            DispatchQueue.main.async {
                completion(.failure(.decodingError(data, error)))
            }
        }
    }

    func handleDeleteResponse(_ data: Data?, _ response: URLResponse?, _ error: Error?, completion: @escaping (Result<Void, OpenAIServiceError>) -> Void) {
        if let error = error {
            logError("Network error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(.networkError(error)))
            }
            return
        }

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            logError("Invalid response: \(String(describing: response))")
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse(response!)))
            }
            return
        }

        DispatchQueue.main.async {
            completion(.success(()))
        }
    }

    // MARK: - Logging

    private func logRequestDetails(_ request: URLRequest, body: [String: Any]?) {
        print("Request URL: \(request.url?.absoluteString ?? "No URL")")
        if let body = body {
            print("Request Body: \(body)")
        }
    }

    private func logResponseData(_ data: Data) {
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Response JSON: \(jsonString)")
        } else {
            print("Unable to convert response data to JSON string")
        }
    }

    private func logError(_ message: String) {
        print("Error: \(message)")
    }

    private func logInfo(_ message: String) {
        print("Info: \(message)")
    }

    // MARK: - API Methods

    func fetchAssistants(completion: @escaping (Result<[Assistant], OpenAIServiceError>) -> Void) {
        let endpoint = "assistants"
        let request = makeRequest(endpoint: endpoint)
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error) { (result: Result<AssistantsResponse, OpenAIServiceError>) in
                switch result {
                case .success(let response):
                    completion(.success(response.data))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    func createAssistant(model: String, name: String? = nil, description: String? = nil, instructions: String? = nil, tools: [[String: Any]]? = nil, toolResources: [String: Any]? = nil, metadata: [String: String]? = nil, temperature: Double? = nil, topP: Double? = nil, responseFormat: ResponseFormat? = nil, completion: @escaping (Result<Assistant, OpenAIServiceError>) -> Void) {
        var body: [String: Any] = ["model": model]
        
        body["name"] = name
        body["description"] = description
        body["instructions"] = instructions
        body["tools"] = tools
        body["tool_resources"] = toolResources
        body["metadata"] = metadata
        body["temperature"] = temperature
        body["top_p"] = topP
        body["response_format"] = responseFormat?.toAny()
        
        let request = makeRequest(endpoint: "assistants", httpMethod: "POST", body: body)
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    func updateAssistant(assistantId: String, model: String? = nil, name: String? = nil, description: String? = nil, instructions: String? = nil, tools: [[String: Any]]? = nil, toolResources: [String: Any]? = nil, metadata: [String: String]? = nil, temperature: Double? = nil, topP: Double? = nil, responseFormat: ResponseFormat? = nil, completion: @escaping (Result<Assistant, OpenAIServiceError>) -> Void) {
        var body: [String: Any] = [:]
        
        body["model"] = model
        body["name"] = name
        body["description"] = description
        body["instructions"] = instructions
        body["tools"] = tools
        body["tool_resources"] = toolResources
        body["metadata"] = metadata
        body["temperature"] = temperature
        body["top_p"] = topP
        body["response_format"] = responseFormat?.toAny()
        
        let request = makeRequest(endpoint: "assistants/\(assistantId)", httpMethod: "POST", body: body)
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    func deleteAssistant(assistantId: String, completion: @escaping (Result<Void, OpenAIServiceError>) -> Void) {
        guard let request = makeRequest(endpoint: "assistants/\(assistantId)", httpMethod: "DELETE") else {
            completion(.failure(.invalidRequest))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleDeleteResponse(data, response, error, completion: completion)
        }.resume()
    }

    func fetchAssistantSettings(assistantId: String, completion: @escaping (Result<AssistantSettings, OpenAIServiceError>) -> Void) {
        let request = makeRequest(endpoint: "assistants/\(assistantId)/settings")
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    func fetchVectorStores() -> Future<[VectorStore], Error> {
        return Future { promise in
            let url = self.baseURL.appendingPathComponent("vector_stores")
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

            self.session.dataTask(with: request) { data, response, error in
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
                    let response = try JSONDecoder().decode(VectorStoreResponse.self, from: data)
                    promise(.success(response.data))
                } catch {
                    promise(.failure(error))
                }
            }.resume()
        }
    }
    
    func fetchFiles(for vectorStoreId: String) -> Future<[File], Error> {
        return Future { promise in
            let url = self.baseURL.appendingPathComponent("vector_stores/\(vectorStoreId)/files")
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

            self.session.dataTask(with: request) { data, response, error in
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
                    let response = try JSONDecoder().decode(VectorStoreFilesResponse.self, from: data)
                    promise(.success(response.data))
                } catch {
                    promise(.failure(error))
                }
            }.resume()
        }
    }
    
    func deleteFile(fileID: String) -> AnyPublisher<Void, Error> {
        guard let url = URL(string: "https://api.openai.com/v1/files/\(fileID)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        return URLSession.shared.dataTaskPublisher(for: request)
            .map { _ in () }  // Ignore the response body
            .mapError { $0 as Error }  // Convert URLError to Error
            .eraseToAnyPublisher()
    }

    func createVectorStore(name: String, files: [[String: Any]], completion: @escaping (Result<VectorStore, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/vector_stores") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

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
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
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

    func updateVectorStore(vectorStoreId: String, name: String? = nil, files: [[String: Any]]? = nil, completion: @escaping (Result<VectorStore, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/vector_stores/\(vectorStoreId)") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        var body: [String: Any] = [:]

        if let name = name {
            body["name"] = name
        }

        if let files = files {
            body["files"] = files
        }

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

    func deleteVectorStore(vectorStoreId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/vector_stores/\(vectorStoreId)") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }.resume()
    }
    
    func fetchVectorStoreDetails(vectorStoreId: String) -> Future<VectorStore, Error> {
        return Future { promise in
            guard let url = URL(string: "https://api.openai.com/v1/vector_stores/\(vectorStoreId)") else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

            URLSession.shared.dataTask(with: request) { data, response, error in
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
                    let vectorStore = try JSONDecoder().decode(VectorStore.self, from: data)
                    promise(.success(vectorStore))
                } catch {
                    promise(.failure(error))
                }
            }.resume()
        }
    }

    func fetchVectorStoreFiles(vectorStoreId: String) -> Future<[File], Error> {
        return Future { promise in
            guard let url = URL(string: "https://api.openai.com/v1/vector_stores/\(vectorStoreId)/files") else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

            URLSession.shared.dataTask(with: request) { data, response, error in
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
                    let response = try JSONDecoder().decode(VectorStoreFilesResponse.self, from: data)
                    promise(.success(response.data))
                } catch {
                    promise(.failure(error))
                }
            }.resume()
        }
    

    func addFileToVectorStore(vectorStoreId: String, file: [String: Any]) -> Future<VectorStore, Error> {
        return Future { promise in
            guard let url = URL(string: "\(self.baseURL)/vector_stores/\(vectorStoreId)/files") else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: file)

            self.session.dataTask(with: request) { data, response, error in
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
                    let vectorStore = try JSONDecoder().decode(VectorStore.self, from: data)
                    promise(.success(vectorStore))
                } catch {
                    promise(.failure(error))
                }
            }.resume()
        }
    }

    func deleteFileFromVectorStore(vectorStoreId: String, fileId: String) -> Future<Void, Error> {
        return Future { promise in
            guard let url = URL(string: "\(self.baseURL)/vector_stores/\(vectorStoreId)/files/\(fileId)") else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")

            self.session.dataTask(with: request) { _, response, error in
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

                promise(.success(()))
            }.resume()
        }
    }
}
    // MARK: - Thread and Message Methods

    func createThread(completion: @escaping (Result<Thread, OpenAIServiceError>) -> Void) {
        guard let request = makeRequest(endpoint: "threads", httpMethod: "POST") else {
            completion(.failure(.invalidRequest))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    func runAssistantOnThread(threadId: String, assistantId: String, completion: @escaping (Result<Run, OpenAIServiceError>) -> Void) {
        let endpoint = "threads/\(threadId)/runs"
        let body: [String: Any] = ["assistant_id": assistantId]
        let request = makeRequest(endpoint: endpoint, httpMethod: "POST", body: body)
        logRequestDetails(request, body: body)
        session.dataTask(with: request) { data, response, error in
            if let data = data {
                self.logResponseData(data)
            }
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    func fetchRunStatus(threadId: String, runId: String, completion: @escaping (Result<Run, OpenAIServiceError>) -> Void) {
        let endpoint = "threads/\(threadId)/runs/\(runId)"
        let request = makeRequest(endpoint: endpoint)
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    func fetchRunMessages(threadId: String, completion: @escaping (Result<[Message], OpenAIServiceError>) -> Void) {
        let endpoint = "threads/\(threadId)/messages"
        let request = makeRequest(endpoint: endpoint)
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                self.logError("Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.logError("Invalid response: \(String(describing: response))")
                DispatchQueue.main.async {
                    completion(.failure(.unknownError))
                }
                return
            }

            if !(200...299).contains(httpResponse.statusCode) {
                self.logError("HTTP error: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse(httpResponse)))
                }
                return
            }

            guard let data = data else {
                self.logError("No data received")
                DispatchQueue.main.async {
                    completion(.failure(.noData))
                }
                return
            }

            self.logResponseData(data)

            do {
                let decodedResponse = try JSONDecoder().decode(MessageResponseList.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(decodedResponse.data))
                }
            } catch {
                self.logError("Decoding error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError(data, error)))
                }
            }
        }.resume()
    }

    // MARK: - Add Message to Thread

    func addMessageToThread(threadId: String, message: Message, completion: @escaping (Result<Void, OpenAIServiceError>) -> Void) {
        let endpoint = "threads/\(threadId)/messages"
        let body: [String: Any] = [
            "role": message.role.rawValue,
            "content": message.content.map { $0.toDictionary() }
        ]
        let request = makeRequest(endpoint: endpoint, httpMethod: "POST", body: body)
        logRequestDetails(request, body: body)
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                self.logError("Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }
            guard let data = data else {
                self.logError("No data received")
                DispatchQueue.main.async {
                    completion(.failure(.noData))
                }
                return
            }
            self.logResponseData(data)
            do {
                let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                self.logError("Decoding error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.decodingError(data, error)))
                }
            }
        }.resume()
    }
    func fetchThreadDetails(threadId: String, completion: @escaping (Result<Thread, OpenAIServiceError>) -> Void) {
        let endpoint = "threads/\(threadId)"
        let request = makeRequest(endpoint: endpoint)
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    func fetchAvailableModels(completion: @escaping (Result<[String], Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

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
                let modelResponse = try JSONDecoder().decode(ModelResponse.self, from: data)
                let modelIds = modelResponse.data.map { $0.id }
                completion(.success(modelIds))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - Upload File Extension

extension OpenAIService {
    func uploadFile(fileData: Data, fileName: String) -> Future<String, Error> {
        return Future { [weak self] promise in
            guard let self = self else { return }
            let url = self.baseURL.appendingPathComponent("files")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            
            // Create the multipart form data body
            let boundary = "Boundary-\(UUID().uuidString)"
            var body = Data()
            
            // Add file field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Add purpose field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
            body.append("assistants".data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            
            // End boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            // Set the request body and content type
            request.httpBody = body
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            self.session.dataTask(with: request) { data, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    promise(.failure(NSError(domain: "", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    return
                }
                
                guard let data = data else {
                    promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let fileId = json?["id"] as? String {
                        promise(.success(fileId))
                    } else {
                        promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response structure"])))
                    }
                } catch {
                    promise(.failure(error))
                }
                
            }.resume()
        }
    }
}

// MARK: - Attach File to Vector Store Extension

extension OpenAIService {
    func attachFileToVectorStore(vectorStoreId: String, fileId: String) -> Future<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else { return }
            let url = self.baseURL.appendingPathComponent("vector_stores/\(vectorStoreId)/files")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = ["file_id": fileId]
            
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            self.session.dataTask(with: request) { _, response, error in
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
                
                promise(.success(()))
                
            }.resume()
        }
    }
}

// MARK: - Create File Batch Extension

extension OpenAIService {
    func createVectorStoreFileBatch(vectorStoreId: String, fileIds: [String]) -> Future<VectorStoreFileBatch, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self was deallocated"])))
                return
            }

            let safeVectorStoreId = vectorStoreId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? vectorStoreId
            
            guard let url = URL(string: "\(self.baseURL.absoluteString)/vector_stores/\(safeVectorStoreId)/file_batches") else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String : Any] = ["file_ids": fileIds]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                
                self.session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                        promise(.failure(NSError(domain:"", code:-1, userInfo:[NSLocalizedDescriptionKey : "Invalid response or status code"])))
                        return
                    }

                    guard let data = data else {
                        promise(.failure(NSError(domain:"", code:-1, userInfo:[NSLocalizedDescriptionKey : "No data received"])))
                        return
                    }

                    do {
                        let batch = try JSONDecoder().decode(VectorStoreFileBatch.self, from:data)
                        promise(.success(batch))
                        
                    } catch {
                        promise(.failure(NSError(domain:"", code:-1,userInfo:[NSLocalizedDescriptionKey : "Decoding error"])))
                        
                    }

                }.resume()

             } catch {
                 promise(.failure(error))
             }
        }
    }
}


// MARK: - Delete File from Vector Store Extension
extension OpenAIService {
    func deleteFileFromVectorStore(vectorStoreId: String, fileId: String) -> Future<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else { return }
            let endpoint = "vector_stores/\(vectorStoreId)/files/\(fileId)"
            guard let request = self.makeRequest(endpoint: endpoint, httpMethod: "DELETE") else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Request"])))
                return
            }
            
            self.session.dataTask(with: request) { _, response, error in
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
                
                promise(.success(()))
            }.resume()
        }
    }
}
