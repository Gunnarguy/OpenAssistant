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

    /**
     Creates a URL request for the specified endpoint with the given HTTP method and optional body.

     - Parameters:
        - endpoint: The endpoint to which the request will be made.
        - httpMethod: The HTTP method for the request (default is "GET").
        - body: The optional body of the request, as a dictionary of key-value pairs.

     - Returns:
        A URLRequest object configured with the specified endpoint, HTTP method, headers, and body.
     */
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

    // MARK: - API Calls
    /**
     Handles the response from the OpenAI API.

     - Parameters:
        - data: The data received from the API response.
        - response: The URLResponse received from the API request.
        - error: The error received from the API request, if any.
        - completion: The completion handler to be called with the result.

     This function decodes the response data into the specified type, checks for errors, and logs relevant information.
     It also calls the completion handler with the result on the main queue.
     */
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

    // MARK: - GET Requests
    /**
     Handles the response for DELETE requests.

     - Parameters:
        - data: The data received in the response.
        - response: The URL response received.
        - error: The error, if any, received during the request.
        - completion: The completion handler to be called with the result.

     This function checks for network errors, invalid responses, and successful deletions.
     If no error is received and the HTTP status code is in the 200-299 range, it calls the completion handler with a success result.
     If an error is received, it logs the error and calls the completion handler with a network error result.
     If an invalid response is received, it logs the response and calls the completion handler with an invalid response result.
     */
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

    /**
     Logs the details of a network request, including the request URL and body.

     - Parameters:
        - request: The URL request to be logged.
        - body: The body of the request, if any.
     */
    private func logRequestDetails(_ request: URLRequest, body: [String: Any]?) {
        print("Request URL: \(request.url?.absoluteString ?? "No URL")")
        if let body = body {
            print("Request Body: \(body)")
        }
    }   

    /**
     Logs the response data received from the OpenAI API.

     This function is used to print the response data in a human-readable format. It converts the data to a JSON string and prints it. If the conversion fails, it prints an error message.

     - Parameter data: The response data received from the OpenAI API.
     */
    private func logResponseData(_ data: Data) {
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Response JSON: \(jsonString)")
        } else {
            print("Unable to convert response data to JSON string")
        }
    }

    /**
     Logs an error message to the console.

     - Parameter message: The error message to be logged.
     */
    private func logError(_ message: String) {
        print("Error: \(message)")
    }

    /**
     Logs an informational message.

     - Parameter message: The message to be logged.
     */
    private func logInfo(_ message: String) {
        print("Info: \(message)")
    }

    // MARK: - API Methods

    /**
     Fetches a list of assistants from the OpenAI API.

     - Parameter completion: A closure that will be called when the request is completed.
     The closure takes a Result parameter, which will be a Result containing an array of Assistant objects
     if the request is successful, or an OpenAIServiceError if the request fails.

     - Important: This function does not handle authentication. You should ensure that the API key
     is set in the `apiKey` property of the `OpenAIService` instance before calling this function.
     */
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

    /**
     Creates a new assistant with the provided parameters.

     - Parameters:
        - model: The model of the assistant.
        - name: The name of the assistant.
        - description: The description of the assistant.
        - instructions: The instructions for the assistant.
        - tools: The tools available to the assistant.
        - toolResources: The resources for the tools.
        - metadata: The metadata for the assistant.
        - temperature: The temperature for the assistant.
        - topP: The top-p value for the assistant.
        - responseFormat: The format of the response.
        - completion: A closure that receives the result of the request.

     - Returns:
        A closure that will be called with the result of the request. The closure will receive a `Result` containing either an `Assistant` or an `OpenAIServiceError`.
     */
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

    /**
     Updates an existing assistant with the provided parameters.

     - Parameters:
        - assistantId: The unique identifier of the assistant to update.
        - model: The model to use for the assistant.
        - name: The name of the assistant.
        - description: A description of the assistant.
        - instructions: Instructions for the assistant.
        - tools: Tools to be used by the assistant.
        - toolResources: Resources for the tools.
        - metadata: Metadata for the assistant.
        - temperature: The temperature for the assistant.
        - topP: The top-p value for the assistant.
        - responseFormat: The format of the assistant's response.
        - completion: A closure to be executed when the request is completed. The closure receives a Result containing either an Assistant or an OpenAIServiceError.

     - Returns: Void
     */
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

    /**
     Deletes an assistant with the given assistant ID.

     - Parameter assistantId: The unique identifier of the assistant to delete.
     - Parameter completion: A closure that will be executed when the request is completed. The closure receives a Result containing either a Void (indicating success) or an OpenAIServiceError (indicating failure).

     - Important: This function does not return a value. Instead, it calls the provided completion closure when the request is completed.
     */
    func deleteAssistant(assistantId: String, completion: @escaping (Result<Void, OpenAIServiceError>) -> Void) {
        guard let request = makeRequest(endpoint: "assistants/\(assistantId)", httpMethod: "DELETE") else {
            completion(.failure(.invalidRequest))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleDeleteResponse(data, response, error, completion: completion)
        }.resume()
    }

    /**
     Fetches the settings for the assistant with the given assistant ID.

     - Parameter assistantId: The unique identifier of the assistant.
     - Parameter completion: A closure that will be executed when the request is completed. The closure receives a Result containing either an AssistantSettings (indicating success) or an OpenAIServiceError (indicating failure).

     - Important: This function does not return a value. Instead, it calls the provided completion closure when the request is completed.
     */
    func fetchAssistantSettings(assistantId: String, completion: @escaping (Result<AssistantSettings, OpenAIServiceError>) -> Void) {
        let request = makeRequest(endpoint: "assistants/\(assistantId)/settings")
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    /**
     Fetches a list of vector stores from the OpenAI API.

     - Parameter completion: A closure that will be called when the request is completed.
     - Parameter promise: A result containing an array of VectorStore objects if the request is successful, or an error if the request fails.
     */
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
    
    /**
     Fetches files associated with a specific vector store.

     - Parameters:
        - vectorStoreId: The ID of the vector store.

     - Returns:
        A Future that resolves to an array of File objects if successful, or an Error if unsuccessful.
     */
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
    
    /**
     Deletes a file from the OpenAI platform.

     - Parameters:
        - fileID: The unique identifier of the file to be deleted.

     - Returns:
        An AnyPublisher that emits a Void value when the file is successfully deleted, or an Error if the deletion fails.
     */
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

    /**
     Creates a new vector store on the OpenAI platform.

     - Parameters:
        - name: The name of the vector store.
        - files: An array of dictionaries representing the files to be added to the vector store. Each dictionary should contain the file's "name" and "file" (as Data).
        - completion: A closure that will be called with the result of the API call. The closure takes a Result parameter, which will be either a `.success` containing the created VectorStore or a `.failure` containing an Error.

     - Important:
        This function requires the `apiKey` property to be set with a valid OpenAI API key.
     */
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

    /**
     Updates an existing Vector Store with the provided name and/or files.

     - Parameters:
        - vectorStoreId: The unique identifier of the Vector Store.
        - name: The new name for the Vector Store. If `nil`, the name will not be updated.
        - files: An array of dictionaries representing the files to be added to the Vector Store. If `nil`, the files will not be updated.
        - completion: A closure that will be called with the result of the operation. The closure will receive a `Result` object, which will be either a `.success` case containing the updated `VectorStore` or a `.failure` case containing an `Error`.

     - Important: This function requires an active internet connection and may incur network data charges.
     */
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

    /**
     Deletes a Vector Store with the provided ID.

     - Parameters:
        - vectorStoreId: The unique identifier of the Vector Store to be deleted.
        - completion: A closure that will be called with the result of the operation. The closure will receive a `Result` object, which will be either a `.success` case containing `Void` (indicating the Vector Store was deleted successfully) or a `.failure` case containing an `Error`.

     - Important: This function requires an active internet connection and may incur network data charges.
     */
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

    /**
     Adds a new message to the specified thread.

     - Parameters:
        - threadId: The unique identifier of the thread.
        - message: The message to be added.
        - completion: A closure that will be called with the result of the operation. The closure will receive a `Result` object, which will be either a `.success` case containing `Void` (indicating the message was added successfully) or a `.failure` case containing an `OpenAIServiceError`.

     - Important: This function does not handle the execution of the assistant's response to the added message. It only adds the message to the thread.
     */
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
    /**
     Fetches the details of a specific thread from the OpenAI API.

     - Parameters:
        - threadId: The unique identifier of the thread.
        - completion: A closure that will be called with the result of the operation. The closure will receive a `Result` object, which will be either a `.success` case containing a `Thread` object (indicating the thread details were fetched successfully) or a `.failure` case containing an `OpenAIServiceError`.

     - Important: This function does not handle the execution of the assistant's response to the fetched thread details. It only fetches the thread details.
     */
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
