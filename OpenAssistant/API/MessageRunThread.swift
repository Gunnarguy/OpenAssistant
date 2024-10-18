import Foundation

// MARK: - Message

struct Message: Identifiable, Codable, Equatable {
    let id: String // Remove the default value
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
