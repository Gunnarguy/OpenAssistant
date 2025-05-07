import Combine
import Foundation
import SwiftUI

class OpenAIService {
    let apiKey: String
    let baseURL = URL(string: "https://api.openai.com/v1/")!
    let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    internal enum HTTPHeaderField: String {
        case authorization = "Authorization"
        case contentType = "Content-Type"
        case openAIBeta = "OpenAI-Beta"
    }

    internal enum ContentType: String {
        case json = "application/json"
        case multipartFormData = "multipart/form-data"
    }

    internal enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        // Removed PATCH as it's not used for assistant updates per docs
    }

    // MARK: - Request Configuration

    /// Creates a URLRequest with common headers.
    func makeRequest(
        endpoint: String, httpMethod: HTTPMethod = .get, body: [String: Any]? = nil,
        contentType: ContentType = .json
    ) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            logError("Invalid URL for endpoint: \(endpoint)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        addCommonHeaders(to: &request, contentType: contentType)

        if let body = body {
            do {
                // Use prettyPrinted for slightly more readable log output
                let jsonData = try JSONSerialization.data(
                    withJSONObject: body, options: [.prettyPrinted])
                request.httpBody = jsonData

                // Log the raw JSON string being sent
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("Serialized JSON Body:\n\(jsonString)")
                } else {
                    print("Serialized JSON Body: <Could not decode as UTF-8>")
                }

                // Keep the original logging as well for context
                logRequestDetails(request, body: body)
            } catch {
                logError("Failed to serialize request body: \(error.localizedDescription)")
                return nil
            }
        } else {
            print("Request Body: <None>")  // Log when body is nil
        }

        return request
    }

    /// Adds common headers required for OpenAI requests
    private func addCommonHeaders(to request: inout URLRequest, contentType: ContentType = .json) {
        request.setValue(
            "Bearer \(apiKey)", forHTTPHeaderField: HTTPHeaderField.authorization.rawValue)
        request.setValue(
            contentType.rawValue, forHTTPHeaderField: HTTPHeaderField.contentType.rawValue)
        request.setValue("assistants=v2", forHTTPHeaderField: HTTPHeaderField.openAIBeta.rawValue)
    }

    // MARK: - Request Execution with Retry

    /// Performs a URLSession data task with retry logic for transient network errors.
    /// - Parameters:
    ///   - request: The URLRequest to execute.
    ///   - currentRetry: The current retry attempt count.
    ///   - maxRetries: The maximum number of retry attempts.
    ///   - initialDelay: The base delay for the first retry, subsequent retries use exponential backoff.
    ///   - completion: Completion handler with the raw `Data?`, `URLResponse?`, and `Error?`.
    func performDataTaskWithRetry(
        _ request: URLRequest,
        currentRetry: Int = 0,
        maxRetries: Int = 2,  // Total 3 attempts (initial + 2 retries)
        initialDelay: TimeInterval = 1.0,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        // Log attempt details
        let attemptNumber = currentRetry + 1
        let totalAttempts = maxRetries + 1
        logInfo(
            "Attempting request to \(request.url?.path ?? "unknown path") (Attempt \(attemptNumber)/\(totalAttempts))"
        )

        session.dataTask(with: request) { data, response, error in
            // Check for specific retryable URLErrors
            if let urlError = error as? URLError,
                urlError.code == .networkConnectionLost || urlError.code == .timedOut
                    || urlError.code == .cannotConnectToHost
                    || urlError.code == .resourceUnavailable,
                currentRetry < maxRetries
            {

                // Calculate delay with exponential backoff
                let delay = initialDelay * pow(2.0, Double(currentRetry))
                // Log failure and retry scheduling
                self.logInfo(
                    "Request to \(request.url?.path ?? "unknown path") failed (Attempt \(attemptNumber)/\(totalAttempts)) with URLError code \(urlError.code.rawValue). Retrying in \(String(format: "%.2f", delay))s..."
                )

                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.performDataTaskWithRetry(
                        request,
                        currentRetry: currentRetry + 1,
                        maxRetries: maxRetries,
                        initialDelay: initialDelay,
                        completion: completion)
                }
                return
            }

            // Log if request succeeded or failed permanently after retries
            if let error = error {
                self.logError(
                    "Request to \(request.url?.path ?? "unknown path") failed permanently after \(attemptNumber) attempt(s). Error: \(error.localizedDescription)"
                )
            } else if let httpResponse = response as? HTTPURLResponse,
                !(200...299).contains(httpResponse.statusCode)
            {
                // Log non-success HTTP status codes
                var responseBodyString: String = "<No data or non-UTF8 data>"
                if let data = data, let bodyStr = String(data: data, encoding: .utf8) {
                    responseBodyString = bodyStr
                }
                self.logError(
                    "Request to \(request.url?.path ?? "unknown path") completed with non-success status code \(httpResponse.statusCode) after \(attemptNumber) attempt(s). Response: \(responseBodyString)"
                )
            } else {
                self.logInfo(
                    "Request to \(request.url?.path ?? "unknown path") succeeded after \(attemptNumber) attempt(s)."
                )
            }

            // If not retrying (e.g., error is not retryable, or retries exhausted, or no error), pass results to completion
            completion(data, response, error)
        }.resume()
    }

    // MARK: - HandleResponse
    internal func handleResponse<T: Decodable>(
        _ data: Data?, _ response: URLResponse?, _ error: Error?,
        completion: @escaping (Result<T, OpenAIServiceError>) -> Void
    ) {
        handleDataTaskResponse(data: data, response: response, error: error) {
            (result: Result<T, Error>) in
            switch result {
            case .success(let decodedResponse):
                DispatchQueue.main.async {
                    completion(.success(decodedResponse))
                }
            case .failure(let error):
                let openAIError = self.mapToOpenAIServiceError(
                    error: error, data: data, response: response)
                DispatchQueue.main.async {
                    completion(.failure(openAIError))
                }
            }
        }
    }

    // MARK: - Handle HTTP Errors
    func handleHTTPError<T>(
        _ httpResponse: HTTPURLResponse, data: Data?,
        completion: @escaping (Result<T, OpenAIServiceError>) -> Void
    ) {
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
            if let data = data {
                do {
                    let apiError = try JSONDecoder().decode(APIError.self, from: data)
                    print(apiError.error.message)
                } catch {
                    print("Decoding error: \(error)")
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse(httpResponse)))
                }
            }
        }
    }

    // MARK: - handleDeleteResponse

    func handleDeleteResponse(
        _ data: Data?, _ response: URLResponse?, _ error: Error?,
        completion: @escaping (Result<Void, OpenAIServiceError>) -> Void
    ) {
        if let error = error {
            logError("Network error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(.networkError(error)))
            }
            return
        }

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
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

    // MARK: - Helper function to map errors
    private func mapToOpenAIServiceError(error: Error, data: Data?, response: URLResponse?)
        -> OpenAIServiceError
    {
        if let error = error as? OpenAIServiceError {
            return error
        }

        if let urlError = error as? URLError {
            return .networkError(urlError)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .unknownError
        }

        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? Int ?? 1
            return .rateLimitExceeded(retryAfter)
        } else if httpResponse.statusCode == 500 {
            return .internalServerError
        } else if let data = data {
            do {
                let apiError = try JSONDecoder().decode(APIError.self, from: data)
                return .custom(apiError.error.message)  // Changed from .apiError to .custom since apiError case doesn't exist
            } catch {
                return .decodingError(data, error)
            }
        } else {
            return .invalidResponse(httpResponse)
        }
    }

    // MARK: - Logging
    internal func logRequestDetails(_ request: URLRequest, body: [String: Any]?) {
        print("Request URL: \(request.url?.absoluteString ?? "No URL")")
        if let body = body {
            print("Request Body: \(body)")
        }
    }

    internal func logError(_ message: String) {
        print("Error: \(message)")
    }

    internal func logInfo(_ message: String) {
        print("Info: \(message)")
    }

    internal func logResponseData(_ data: Data) {
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Response JSON: \(jsonString)")
        } else {
            print("Unable to convert response data to JSON string")
        }
    }

    // MARK: - Fetch Vector Store Files
    func fetchVectorStoreFiles(vectorStoreId: String) -> Future<[File], Error> {
        return Future { [self] promise in
            guard let url = URL(string: "\(self.baseURL)vector_stores/\(vectorStoreId)/files")
            else {
                promise(
                    .failure(
                        NSError(
                            domain: "", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
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

                guard let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode)
                else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorDescription = HTTPURLResponse.localizedString(
                        forStatusCode: statusCode)
                    promise(
                        .failure(
                            NSError(
                                domain: "", code: statusCode,
                                userInfo: [NSLocalizedDescriptionKey: errorDescription])))
                    return
                }

                guard let data = data else {
                    promise(
                        .failure(
                            NSError(
                                domain: "", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }

                do {
                    let response = try JSONDecoder().decode(
                        VectorStoreFilesResponse.self, from: data)
                    promise(.success(response.data))
                } catch {
                    promise(.failure(error))
                }
            }.resume()
        }
    }

    // MARK: - Delete File from Vector Store
    func deleteFileFromVectorStore(vectorStoreId: String, fileId: String) -> Future<Void, Error> {
        return Future { [self] promise in
            guard
                let url = URL(
                    string: "\(self.baseURL)vector_stores/\(vectorStoreId)/files/\(fileId)")
            else {
                promise(
                    .failure(
                        NSError(
                            domain: "", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
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

                guard let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode)
                else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorDescription = HTTPURLResponse.localizedString(
                        forStatusCode: statusCode)
                    promise(
                        .failure(
                            NSError(
                                domain: "", code: statusCode,
                                userInfo: [NSLocalizedDescriptionKey: errorDescription])))
                    return
                }

                promise(.success(()))
            }.resume()
        }
    }

    func fetchAvailableModels(completion: @escaping (Result<[String], Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            completion(
                .failure(
                    NSError(
                        domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            )
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Use the new retry mechanism
        performDataTaskWithRetry(request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
                // Attempt to decode error message from OpenAI if available
                if let data = data,
                    let apiError = try? JSONDecoder().decode(APIError.self, from: data)
                {
                    completion(
                        .failure(
                            NSError(
                                domain: "OpenAPIError",
                                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                                userInfo: [NSLocalizedDescriptionKey: apiError.error.message])))
                } else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorDescription = HTTPURLResponse.localizedString(
                        forStatusCode: statusCode)
                    completion(
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
                completion(
                    .failure(
                        NSError(
                            domain: "NetworkError", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            do {
                // Decode the models list
                let modelsList = try JSONDecoder().decode(ModelsListResponse.self, from: data)
                let modelIds = modelsList.data.map { $0.id }
                completion(.success(modelIds))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Responses API
/// Encodable request model for v1/responses endpoint
struct ResponseRequest: Codable {
    let model: String
    let input: String
    let temperature: Double?
    let top_p: Double?
    let max_output_tokens: Int?
    let stream: Bool?
    let include: [String]?
    let tool_choice: String?
    let parallel_tool_calls: Bool?
}

extension OpenAIService {
    /// Create a model response with advanced options
    func createResponse(
        request: ResponseRequest,
        completion: @escaping (Result<ResponseResult, OpenAIServiceError>) -> Void
    ) {
        // Encode request to JSON and convert to dictionary
        guard let jsonData = try? JSONEncoder().encode(request),
            let body = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            let urlRequest = makeRequest(endpoint: "responses", httpMethod: .post, body: body)
        else {
            completion(.failure(.invalidRequest))
            return
        }
        // Use the new retry mechanism
        performDataTaskWithRetry(urlRequest) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }
    }

    /// Retrieve a model response by ID
    func getResponse(
        responseId: String,
        completion: @escaping (Result<ResponseResult, OpenAIServiceError>) -> Void
    ) {
        let endpoint = "responses/\(responseId)"
        guard let request = makeRequest(endpoint: endpoint) else {
            completion(.failure(.invalidRequest))
            return
        }
        // Use the new retry mechanism
        performDataTaskWithRetry(request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }
    }
}

// MARK: - ModelResponse Models
/// Represents a response from the OpenAI v1/responses API
struct ResponseResult: Codable {
    let id: String
    let object: String
    let created_at: Int
    let status: String
    let output: [ResponseOutput]
}

/// Individual output items in a model response
struct ResponseOutput: Codable {
    let type: String  // e.g., "message", "file_search_call"
    let id: String?
    let role: String?  // for message items
    let content: [OutputContent]?  // for message items
}

/// Content within a message output
struct OutputContent: Codable {
    let type: String  // e.g., "output_text"
    let text: String?
}

extension OpenAIService {
    func handleDataTaskResponse<T: Decodable>(
        data: Data?, response: URLResponse?, error: Error?,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
            completion(
                .failure(
                    NSError(
                        domain: "", code: statusCode,
                        userInfo: [NSLocalizedDescriptionKey: errorDescription])))
            return
        }

        guard let data = data else {
            completion(
                .failure(
                    NSError(
                        domain: "", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            return
        }

        do {
            let decodedResponse = try JSONDecoder().decode(T.self, from: data)
            completion(.success(decodedResponse))
        } catch {
            completion(.failure(error))
        }
    }
}
