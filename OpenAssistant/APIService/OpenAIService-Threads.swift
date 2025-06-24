import Combine
import Foundation
import SwiftUI

extension OpenAIService {

    // MARK: - Create Thread
    func createThread(completion: @escaping (Result<Thread, OpenAIServiceError>) -> Void) {
        guard let request = makeRequest(endpoint: "threads", httpMethod: .post) else {
            completion(.failure(.custom("Failed to create request")))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    // MARK: - Run Assistant on Thread
    func runAssistantOnThread(
        threadId: String, assistantId: String,
        completion: @escaping (Result<Run, OpenAIServiceError>) -> Void
    ) {
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

    // MARK: - Fetch Run Status
    func fetchRunStatus(
        threadId: String, runId: String,
        completion: @escaping (Result<Run, OpenAIServiceError>) -> Void
    ) {
        let endpoint = "threads/\(threadId)/runs/\(runId)"
        guard let request = makeRequest(endpoint: endpoint) else {
            completion(.failure(.custom("Failed to create request")))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    // MARK: - Fetch Run Messages
    func fetchRunMessages(
        threadId: String, completion: @escaping (Result<[Message], OpenAIServiceError>) -> Void
    ) {
        let endpoint = "threads/\(threadId)/messages"
        guard let request = makeRequest(endpoint: endpoint) else {
            completion(.failure(.custom("Failed to create request")))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error) {
                (result: Result<MessageResponseList, OpenAIServiceError>) in
                switch result {
                case .success(let responseList):
                    completion(.success(responseList.data))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Add Message to Thread
    func addMessageToThread(
        threadId: String, message: Message,
        completion: @escaping (Result<Void, OpenAIServiceError>) -> Void
    ) {
        let endpoint = "threads/\(threadId)/messages"
        let body: [String: Any] = [
            "role": message.role.rawValue,
            "content": message.content.map { $0.toDictionary() },
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

            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
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

    // MARK: - Fetch Thread Details
    func fetchThreadDetails(
        threadId: String, completion: @escaping (Result<Thread, OpenAIServiceError>) -> Void
    ) {
        let endpoint = "threads/\(threadId)"
        guard let request = makeRequest(endpoint: endpoint) else {
            completion(.failure(.custom("Failed to create request")))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
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
                "annotations": annotations.map { $0.toDictionary() },
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
            case type, text
            case startIndex = "start_index"
            case endIndex = "end_index"
            case fileCitation = "file_citation"
        }

        func toDictionary() -> [String: Any] {
            var dict: [String: Any] = [
                "type": type,
                "text": text,
                "start_index": startIndex,
                "end_index": endIndex,
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
        case id, object, created_at, assistant_id, thread_id, run_id, role, content, attachments,
            metadata
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
        case id, object, created_at, assistant_id, thread_id, status, started_at, expires_at,
            cancelled_at, failed_at, completed_at, required_action, last_error, model, instructions,
            tools, tool_resources, metadata, temperature, top_p, max_completion_tokens,
            max_prompt_tokens, truncation_strategy, usage, response_format, tool_choice,
            parallel_tool_calls, incomplete_details
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
struct Thread: Identifiable, Codable, Equatable {  // Add Codable (Encodable + Decodable)
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

    static func == (lhs: Thread, rhs: Thread) -> Bool {
        return lhs.id == rhs.id
    }
}
