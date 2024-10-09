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

    private func makeRequest(endpoint: String, httpMethod: String = "GET", body: [String: Any]? = nil) -> URLRequest {
        let safeEndpoint = endpoint.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? endpoint
        var request = URLRequest(url: baseURL.appendingPathComponent(safeEndpoint))
        // Initialize organizationId and projectId
        let organizationId: String? = nil
        let projectId: String? = nil
        request.httpMethod = httpMethod
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: HTTPHeaderField.authorization.rawValue)
        request.addValue(ContentType.json.rawValue, forHTTPHeaderField: HTTPHeaderField.contentType.rawValue)
        request.addValue("assistants=v2", forHTTPHeaderField: HTTPHeaderField.openAIBeta.rawValue)

        if let organizationId = organizationId {
            request.addValue(organizationId, forHTTPHeaderField: "OpenAI-Organization")
        }
        if let projectId = projectId {
            request.addValue(projectId, forHTTPHeaderField: "OpenAI-Project")
        }

        return request
    }

    // MARK: - API Calls

    private func handleResponse<T: Decodable>(_ data: Data?, _ response: URLResponse?, _ error: Error?, completion: @escaping (Result<T, OpenAIServiceError>) -> Void) {
        if let error = error {
            logError("Network error: \(error.localizedDescription)")
            completion(.failure(.networkError(error)))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(.unknownError))
            return

        }

        logInfo("HTTP Status Code: \(httpResponse.statusCode)")
        if let data = data { logResponseData(data) }

        switch httpResponse.statusCode {
        case 200...299:
            guard let data = data else {
                logError("No data received")
                completion(.failure(.noData))
                return
            }

            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decodedResponse))

            } catch {
                logError("Decoding error: \(error.localizedDescription)")
                logError("Response data: \(String(data: data, encoding: .utf8) ?? "N/A")")
                completion(.failure(.decodingError(data, error)))
            }
        case 429:
            let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? Int ?? 1
            completion(.failure(.rateLimitExceeded(retryAfter)))
        case 500:
            completion(.failure(.internalServerError))
        default:
            if let data = data, let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                if httpResponse.statusCode == 401 {
                    completion(.failure(.authenticationError(errorResponse.error?.message)))
                } else if httpResponse.statusCode == 400 {
                    completion(.failure(.invalidRequestError(errorResponse.error?.message)))
                } else {
                    completion(.failure(.invalidResponse(httpResponse)))  // Keep as a fallback
                }
                return
            } else {
                completion(.failure(.invalidResponse(httpResponse)))
            }
        }
    }
    struct OpenAIErrorResponse: Decodable {
        let error: ErrorDetail?
        
        struct ErrorDetail: Decodable {
            let message: String?
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

    // MARK: - Create Assistant
    func createAssistant(
        model: String,
        name: String? = nil,
        description: String? = nil,
        instructions: String? = nil,
        tools: [[String: Any]]? = nil,
        toolResources: [String: Any]? = nil,
        metadata: [String: String]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        responseFormat: ResponseFormat? = nil,
        completion: @escaping (Result<Assistant, OpenAIServiceError>) -> Void
    ) {
        var body: [String: Any] = ["model": model]

        if let name = name {
            body["name"] = name
        }
        if let description = description {
            body["description"] = description
        }
        if let instructions = instructions {
            body["instructions"] = instructions
        }
        if let tools = tools {
            body["tools"] = tools
        }
        if let toolResources = toolResources {
            body["tool_resources"] = toolResources
        }
        if let metadata = metadata {
            body["metadata"] = metadata
        }
        if let temperature = temperature {
            body["temperature"] = temperature
        }
        if let topP = topP {
            body["top_p"] = topP
        }
        if let responseFormat = responseFormat {
            body["response_format"] = responseFormat.toAny()
        }

        let request = makeRequest(endpoint: "assistants", httpMethod: "POST", body: body)
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    // MARK: - Update Assistant
    func updateAssistant(
        assistantId: String,
        model: String? = nil,
        name: String? = nil,
        description: String? = nil,
        instructions: String? = nil,
        tools: [[String: Any]]? = nil,
        toolResources: [String: Any]? = nil,
        metadata: [String: String]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        responseFormat: ResponseFormat? = nil,
        completion: @escaping (Result<Assistant, OpenAIServiceError>) -> Void
    ) {
        var body: [String: Any] = [:]

        if let model = model {
            body["model"] = model
        }
        if let name = name {
            body["name"] = name
        }
        if let description = description {
            body["description"] = description
        }
        if let instructions = instructions {
            body["instructions"] = instructions
        }
        if let tools = tools {
            body["tools"] = tools
        }
        if let toolResources = toolResources {
            body["tool_resources"] = toolResources
        }
        if let metadata = metadata {
            body["metadata"] = metadata
        }
        if let temperature = temperature {
            body["temperature"] = temperature
        }
        if let topP = topP {
            body["top_p"] = topP
        }
        if let responseFormat = responseFormat {
            body["response_format"] = responseFormat.toAny()
        }

        let request = makeRequest(endpoint: "assistants/\(assistantId)", httpMethod: "POST", body: body)
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    // Dummy struct to conform to Decodable for DELETE requests with no body
    private struct EmptyResponse: Decodable {}

    func deleteAssistant(assistantId: String, completion: @escaping (Result<Void, OpenAIServiceError>) -> Void) {
        let request = makeRequest(endpoint: "assistants/\(assistantId)", httpMethod: "DELETE")
        session.dataTask(with: request!) { data, response, error in
            // Use the EmptyResponse type
            self.handleResponse(data, response, error) { (result: Result<EmptyResponse, OpenAIServiceError>) in
                switch result {
                case .success:
                    completion(.success(())) // Success, no body to process
                case .failure(let error):
                    completion(.failure(error))
                }
            }
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

    func createVectorStore(name: String, fileIds: [String], completion: @escaping (Result<VectorStore, Error>) -> Void) {
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
            "file_ids": fileIds
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
                let vectorStore = try JSONDecoder().decode(VectorStore.self, from: data)
                completion(.success(vectorStore))
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

    func deleteVectorStore(vectorStoreId: String) -> AnyPublisher<Void, Error> {
        let url = baseURL.appendingPathComponent("vector_stores/\(vectorStoreId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta") // Add this line

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                // Decode the response to check the deletion status
                let deleteResponse = try JSONDecoder().decode(DeleteResponse.self, from: data)
                guard deleteResponse.deleted else {
                    throw URLError(.cannotParseResponse)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
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
    

        // MARK: - Add File to Vector Store
        func addFileToVectorStore(vectorStoreId: String, fileData: Data, fileName: String) -> Future<VectorStore, Error> {
            return Future { promise in
                guard let url = URL(string: "\(self.baseURL)/vector_stores/\(vectorStoreId)/files") else {
                    promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let file: [String: Any] = [
                    "file_name": fileName,
                    "file_data": fileData.base64EncodedString()
                ]
                
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
                _ = try JSONDecoder().decode(OpenAIResponse.self, from: data)
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
    
    func fetchThreadDetails(threadId: String) -> Future<Thread, OpenAIServiceError> {
        return Future { promise in
            let endpoint = "threads/\(threadId)"
            let request = self.makeRequest(endpoint: endpoint)
            self.session.dataTask(with: request) { data, response, error in
                self.handleResponse(data, response, error) { (result: Result<Thread, OpenAIServiceError>) in
                    switch result {
                    case .success(let thread):
                        promise(.success(thread))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
            }.resume()
        }
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
        Future { [weak self] promise in
            guard let self = self else { return }
            
            // Construct the URL
            let url = self.baseURL.appendingPathComponent("files")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: HTTPHeaderField.authorization.rawValue)
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            // Construct body data
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body

            // Perform the request
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
                    let response = try JSONDecoder().decode(FileUploadResponse.self, from: data)
                    promise(.success(response.fileId))
                } catch {
                    promise(.failure(error))
                }
            }.resume()
        }
    }
}

    
    
// MARK: - Create File Batch Extension

extension OpenAIService {
    func createVectorStoreFileBatch(vectorStoreId: String, fileIds: [String]) -> Future<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else { return }
            
            // Encode the vectorStoreId for safe URL usage
            let safeVectorStoreId = vectorStoreId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? vectorStoreId
            
            // Construct the URL
            guard let url = URL(string: "\(self.baseURL.absoluteString)/vector_stores/\(safeVectorStoreId)/file_batches") else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            
            // Set up the request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Prepare the request body
            let body: [String: Any] = ["file_ids": fileIds]
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                
                // Perform the network request
                self.session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                        promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response or status code"])))
                        return
                    }
                    promise(.success(()))
                }.resume()
            } catch {
                promise(.failure(error))
            }
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
    
    // MARK: - Delete File from Vector Store Extension
    extension OpenAIService {
        func deleteFileFromVectorStore(vectorStoreId: String, fileId: String) -> Future<Void, Error> {
            Future { [weak self] promise in
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

