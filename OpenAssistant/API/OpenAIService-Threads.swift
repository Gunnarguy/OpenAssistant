import Foundation
import Combine
import SwiftUI

// MARK: - Thread Management
extension OpenAIService {
    
    // MARK: - Create Thread
    
    /**
     Creates a new thread for conversations with the assistant.
     
     - Parameter completion: Callback with Result containing Thread on success or OpenAIServiceError on failure
     */
    func createThread(completion: @escaping (Result<Thread, OpenAIServiceError>) -> Void) {
        guard let request = makeRequest(endpoint: "threads", httpMethod: .post) else {
            completion(.failure(.custom("Failed to create request")))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }
    
    /**
     Creates a new thread using async/await.
     
     - Returns: A new Thread object
     - Throws: OpenAIServiceError if the request fails
     */
    @available(iOS 15.0, *)
    func createThread() async throws -> Thread {
        guard let request = makeRequest(endpoint: "threads", httpMethod: .post) else {
            throw OpenAIServiceError.invalidRequest
        }
        
        let (data, response) = try await session.data(for: request)
        return try self.decodeResponse(data: data, response: response)
    }

    // MARK: - Run Assistant on Thread
    
    /**
     Runs an assistant on the specified thread.
     
     - Parameters:
        - threadId: The ID of the thread
        - assistantId: The ID of the assistant to run
        - completion: Callback with Result containing Run on success or OpenAIServiceError on failure
     */
    func runAssistantOnThread(threadId: String, assistantId: String, completion: @escaping (Result<Run, OpenAIServiceError>) -> Void) {
        let endpoint = "threads/\(threadId)/runs"
        let body: [String: Any] = ["assistant_id": assistantId]
        guard let request = makeRequest(endpoint: endpoint, httpMethod: .post, body: body) else {
            completion(.failure(.custom("Failed to create request")))
            return
        }
        logRequestDetails(request, body: body)
        session.dataTask(with: request) { data, response, error in
            if let data = data {
                self.logResponseData(data)
            }
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }
    
    /**
     Runs an assistant on a thread using async/await.
     
     - Parameters:
        - threadId: The ID of the thread
        - assistantId: The ID of the assistant to run
     - Returns: Run object containing details about the run
     - Throws: OpenAIServiceError if the request fails
     */
    @available(iOS 15.0, *)
    func runAssistantOnThread(threadId: String, assistantId: String) async throws -> Run {
        let endpoint = "threads/\(threadId)/runs"
        let body: [String: Any] = ["assistant_id": assistantId]
        
        guard let request = makeRequest(endpoint: endpoint, httpMethod: .post, body: body) else {
            throw OpenAIServiceError.invalidRequest
        }
        
        logRequestDetails(request, body: body)
        let (data, response) = try await session.data(for: request)
        
        if let data = data {
            self.logResponseData(data)
        }
        
        return try self.decodeResponse(data: data, response: response)
    }
    
    // MARK: - Fetch Run Status
    
    /**
     Fetches the status of a run.
     
     - Parameters:
        - threadId: The ID of the thread
        - runId: The ID of the run
        - completion: Callback with Result containing Run on success or OpenAIServiceError on failure
     */
    func fetchRunStatus(threadId: String, runId: String, completion: @escaping (Result<Run, OpenAIServiceError>) -> Void) {
        let endpoint = "threads/\(threadId)/runs/\(runId)"
        guard let request = makeRequest(endpoint: endpoint) else {
            completion(.failure(.custom("Failed to create request")))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }
    
    /**
     Fetches the status of a run using async/await.
     
     - Parameters:
        - threadId: The ID of the thread
        - runId: The ID of the run
     - Returns: Run object with updated status
     - Throws: OpenAIServiceError if the request fails
     */
    @available(iOS 15.0, *)
    func fetchRunStatus(threadId: String, runId: String) async throws -> Run {
        let endpoint = "threads/\(threadId)/runs/\(runId)"
        
        guard let request = makeRequest(endpoint: endpoint) else {
            throw OpenAIServiceError.invalidRequest
        }
        
        let (data, response) = try await session.data(for: request)
        return try self.decodeResponse(data: data, response: response)
    }
    
    // MARK: - Fetch Run Messages
    
    /**
     Fetches messages for a thread.
     
     - Parameters:
        - threadId: The ID of the thread
        - completion: Callback with Result containing array of Messages on success or OpenAIServiceError on failure
     */
    func fetchRunMessages(threadId: String, completion: @escaping (Result<[Message], OpenAIServiceError>) -> Void) {
        let endpoint = "threads/\(threadId)/messages"
        guard let request = makeRequest(endpoint: endpoint) else {
            completion(.failure(.custom("Failed to create request")))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error) { (result: Result<MessageResponseList, OpenAIServiceError>) in
                switch result {
                case .success(let responseList):
                    completion(.success(responseList.data))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /**
     Fetches messages for a thread using async/await.
     
     - Parameter threadId: The ID of the thread
     - Returns: Array of Message objects
     - Throws: OpenAIServiceError if the request fails
     */
    @available(iOS 15.0, *)
    func fetchRunMessages(threadId: String) async throws -> [Message] {
        let endpoint = "threads/\(threadId)/messages"
        
        guard let request = makeRequest(endpoint: endpoint) else {
            throw OpenAIServiceError.invalidRequest
        }
        
        let (data, response) = try await session.data(for: request)
        let responseList: MessageResponseList = try self.decodeResponse(data: data, response: response)
        return responseList.data
    }
    
    // MARK: - Add Message to Thread
    
    /**
     Adds a message to a thread.
     
     - Parameters:
        - threadId: The ID of the thread
        - message: Message to add to the thread
        - completion: Callback with Result containing Void on success or OpenAIServiceError on failure
     */
    func addMessageToThread(threadId: String, message: Message, completion: @escaping (Result<Void, OpenAIServiceError>) -> Void) {
        let endpoint = "threads/\(threadId)/messages"
        let body: [String: Any] = [
            "role": message.role.rawValue,
            "content": message.content.map { $0.toDictionary() }
        ]
        guard let request = makeRequest(endpoint: endpoint, httpMethod: .post, body: body) else {
            completion(.failure(.custom("Failed to create request")))
            return
        }
        logRequestDetails(request, body: body)
        session.dataTask(with: request) { data, response, error in
            // Simply check for a successful response, we don't need to decode a specific type
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse(response!)))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(()))
            }
        }.resume()
    }
    
    /**
     Adds a message to a thread using async/await.
     
     - Parameters:
        - threadId: The ID of the thread
        - message: Message to add to the thread
     - Throws: OpenAIServiceError if the request fails
     */
    @available(iOS 15.0, *)
    func addMessageToThread(threadId: String, message: Message) async throws {
        let endpoint = "threads/\(threadId)/messages"
        let body: [String: Any] = [
            "role": message.role.rawValue,
            "content": message.content.map { $0.toDictionary() }
        ]
        
        guard let request = makeRequest(endpoint: endpoint, httpMethod: .post, body: body) else {
            throw OpenAIServiceError.invalidRequest
        }
        
        logRequestDetails(request, body: body)
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw OpenAIServiceError.invalidResponse(response)
        }
    }
    
    // MARK: - Fetch Thread Details
    
    /**
     Fetches details for a thread.
     
     - Parameters:
        - threadId: The ID of the thread
        - completion: Callback with Result containing Thread on success or OpenAIServiceError on failure
     */
    func fetchThreadDetails(threadId: String, completion: @escaping (Result<Thread, OpenAIServiceError>) -> Void) {
        let endpoint = "threads/\(threadId)"
        guard let request = makeRequest(endpoint: endpoint) else {
            completion(.failure(.custom("Failed to create request")))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }
    
    /**
     Fetches thread details using async/await.
     
     - Parameter threadId: The ID of the thread
     - Returns: Thread object with details
     - Throws: OpenAIServiceError if the request fails
     */
    @available(iOS 15.0, *)
    func fetchThreadDetails(threadId: String) async throws -> Thread {
        let endpoint = "threads/\(threadId)"
        
        guard let request = makeRequest(endpoint: endpoint) else {
            throw OpenAIServiceError.invalidRequest
        }
        
        let (data, response) = try await session.data(for: request)
        return try self.decodeResponse(data: data, response: response)
    }
    
    // MARK: - Helper Methods
    
    /**
     Decodes an API response into the specified type.
     
     - Parameters:
        - data: The response data
        - response: The HTTP response
     - Returns: Decoded object of type T
     - Throws: OpenAIServiceError if decoding fails or response is invalid
     */
    @available(iOS 15.0, *)
    private func decodeResponse<T: Decodable>(data: Data, response: URLResponse) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse(response)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? Int ?? 1
                throw OpenAIServiceError.rateLimitExceeded(retryAfter)
            } else if httpResponse.statusCode == 500 {
                throw OpenAIServiceError.internalServerError
            } else {
                throw OpenAIServiceError.invalidResponse(httpResponse)
            }
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw OpenAIServiceError.decodingError(data, error)
        }
    }
}


// MARK: - Message
struct Message: Identifiable, Codable, Equatable {
    let id: String
    let object: String
    let created_at: Int
    let assistant_id: String?
    let thread_id: String
    let run_id: String?
    let role: Role
    let content: [Content]
    let attachments: [String]
    let metadata: [String: String]

    enum Role: String, Codable {
        case user
        case assistant
    }

    struct Content: Codable, Equatable {
        let type: String
        let text: Text?

        private enum CodingKeys: String, CodingKey {
            case type, text
        }

        func toDictionary() -> [String: Any] {
            var dict: [String: Any] = ["type": type]
            if let text = text {
                dict["text"] = text.value
            }
            return dict
        }
    }

    struct Text: Codable, Equatable {
        let value: String
        let annotations: [Annotation]

        private enum CodingKeys: String, CodingKey {
            case value, annotations
        }
        
        func toDictionary() -> [String: Any] {
            return [
                "value": value,
                "annotations": annotations.map { $0.toDictionary() }
            ]
        }
    }

    struct Annotation: Codable, Equatable {
        let type: String
        let text: String
        let startIndex: Int
        let endIndex: Int
        let fileCitation: FileCitation?

        private enum CodingKeys: String, CodingKey {
            case type, text, startIndex = "start_index", endIndex = "end_index", fileCitation = "file_citation"
        }
        
        func toDictionary() -> [String: Any] {
            var dict: [String: Any] = [
                "type": type,
                "text": text,
                "start_index": startIndex,
                "end_index": endIndex
            ]
            if let fileCitation = fileCitation {
                dict["file_citation"] = fileCitation.toDictionary()
            }
            return dict
        }
    }

    struct FileCitation: Codable, Equatable {
        let fileId: String

        private enum CodingKeys: String, CodingKey {
            case fileId = "file_id"
        }
        
        func toDictionary() -> [String: Any] {
            return [
                "file_id": fileId
            ]
        }
    }
}

// MARK: - MessageResponse
struct MessageResponse: Codable, Equatable {
    let id: String
    let object: String
    let created_at: Int
    let assistant_id: String?
    let thread_id: String
    let run_id: String?
    let role: String
    let content: [Message.Content]
    let attachments: [String]
    let metadata: [String: String]

    private enum CodingKeys: String, CodingKey {
        case id, object, created_at, assistant_id, thread_id, run_id, role, content, attachments, metadata
    }
}

// MARK: - MessageResponseList
struct MessageResponseList: Codable {
    let object: String
    let data: [Message]
    let first_id: String?
    let last_id: String?
    let has_more: Bool
}

// MARK: - Run
struct Run: Decodable {
    let id: String
    let object: String
    let created_at: Int
    let assistant_id: String
    let thread_id: String
    let status: String
    let started_at: Int?
    let expires_at: Int?
    let cancelled_at: Int?
    let failed_at: Int?
    let completed_at: Int?
    let required_action: String?
    let last_error: String?
    let model: String
    let instructions: String
    let tools: [Tool]
    let tool_resources: ToolResources?
    let metadata: [String: String]?
    let temperature: Double
    let top_p: Double
    let max_completion_tokens: Int?
    let max_prompt_tokens: Int?
    let truncation_strategy: TruncationStrategy?
    let usage: Usage?
    let response_format: ResponseFormat
    let tool_choice: String
    let parallel_tool_calls: Bool
    let incomplete_details: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, object, created_at, assistant_id, thread_id, status, started_at, expires_at, cancelled_at, failed_at, completed_at, required_action, last_error, model, instructions, tools, tool_resources, metadata, temperature, top_p, max_completion_tokens, max_prompt_tokens, truncation_strategy, usage, response_format, tool_choice, parallel_tool_calls, incomplete_details
    }
}

// MARK: - RunResult
struct RunResult: Decodable, Equatable {
    let content: [Message.Content]

    private enum CodingKeys: String, CodingKey {
        case content
    }
}

// MARK: - Thread
struct Thread: Identifiable, Decodable, Equatable {
    let id: String
    let object: String
    let created_at: Int
    let metadata: [String: String]?
    let tool_resources: ToolResources?
    let messages: [Message]?

    private enum CodingKeys: String, CodingKey {
        case id, object, metadata, messages
        case created_at
        case tool_resources
    }

    static func ==(lhs: Thread, rhs: Thread) -> Bool {
        return lhs.id == rhs.id
    }
}
