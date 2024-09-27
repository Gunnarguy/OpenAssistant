import Foundation
import Combine
import SwiftUI

// MARK: - Assistant
struct Assistant: Identifiable, Codable, Equatable {
    let id: String
    let object: String
    let created_at: Int
    var name: String
    var description: String?
    var model: String
    var instructions: String?
    var threads: [Thread]?
    var tools: [Tool]
    var top_p: Double
    var temperature: Double
    var tool_resources: ToolResources?
    var metadata: [String: String]?
    var response_format: ResponseFormat?
    var file_ids: [String]? // Added property

    static func ==(lhs: Assistant, rhs: Assistant) -> Bool {
        return lhs.id == rhs.id
    }

    private enum CodingKeys: String, CodingKey {
        case id, object, created_at, name, description, model, instructions, tools, top_p, temperature, tool_resources, metadata, response_format, file_ids
    }

    func toAssistantDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "model": model,
            "temperature": temperature,
            "top_p": top_p,
            "instructions": instructions ?? "",
            "metadata": metadata ?? [:],
            "tools": tools.map { $0.toDictionary() }
        ]
        if let toolResources = tool_resources {
            dict["tool_resources"] = toolResources.toDictionary()
        }
        if let responseFormat = response_format {
            dict["response_format"] = responseFormat.toAny()
        }
        if let fileIds = file_ids {
            dict["file_ids"] = fileIds
        }
        return dict
    }
}

// MARK: - AssistantsResponse
struct AssistantsResponse: Decodable, Equatable {
    let object: String
    let data: [Assistant]
    let first_id: String?
    let last_id: String?
    let has_more: Bool

    private enum CodingKeys: String, CodingKey {
        case object, data, first_id, last_id, has_more
    }
}

// MARK: - Tool
struct Tool: Codable {
    var type: String
    var maxNumResults: Int?
    var function: FunctionTool?
    var retrieval: RetrievalTool? // Added property

    private enum CodingKeys: String, CodingKey {
        case type
        case maxNumResults = "max_num_results"
        case function
        case retrieval
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let maxNumResults = maxNumResults {
            dict["max_num_results"] = maxNumResults
        }
        if let function = function {
            dict["function"] = function.toDictionary()
        }
        if let retrieval = retrieval {
            dict["retrieval"] = retrieval.toDictionary()
        }
        return dict
    }
}

// MARK: - FunctionTool
struct FunctionTool: Codable {
    var description: String?
    var name: String
    var parameters: [String: Any]?

    private enum CodingKeys: String, CodingKey {
        case description
        case name
        case parameters
    }

    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
        try container.encode(name, forKey: .name)
        if let parameters = parameters {
            let data = try JSONSerialization.data(withJSONObject: parameters, options: [])
            let jsonString = String(data: data, encoding: .utf8)
            try container.encode(jsonString, forKey: .parameters)
        }
    }

    // Custom decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        name = try container.decode(String.self, forKey: .name)
        if let jsonString = try container.decodeIfPresent(String.self, forKey: .parameters) {
            let data = jsonString.data(using: .utf8)!
            parameters = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } else {
            parameters = nil
        }
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["name": name]
        if let description = description {
            dict["description"] = description
        }
        if let parameters = parameters {
            dict["parameters"] = parameters
        }
        return dict
    }
}

// MARK: - RetrievalTool
struct RetrievalTool: Codable {
    var description: String?
    var name: String
    var options: [String: Any]?

    private enum CodingKeys: String, CodingKey {
        case description
        case name
        case options
    }

    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
        try container.encode(name, forKey: .name)
        if let options = options {
            let data = try JSONSerialization.data(withJSONObject: options, options: [])
            let jsonString = String(data: data, encoding: .utf8)
            try container.encode(jsonString, forKey: .options)
        }
    }

    // Custom decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        name = try container.decode(String.self, forKey: .name)
        if let jsonString = try container.decodeIfPresent(String.self, forKey: .options) {
            let data = jsonString.data(using: .utf8)!
            options = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } else {
            options = nil
        }
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["name": name]
        if let description = description {
            dict["description"] = description
        }
        if let options = options {
            dict["options"] = options
        }
        return dict
    }
}

// MARK: - ToolResources
struct ToolResources: Codable {
    var fileSearch: FileSearchResources?
    var codeInterpreter: CodeInterpreterResources?

    private enum CodingKeys: String, CodingKey {
        case fileSearch = "file_search"
        case codeInterpreter = "code_interpreter"
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let fileSearch = fileSearch {
            dict["file_search"] = fileSearch.toDictionary()
        }
        if let codeInterpreter = codeInterpreter {
            dict["code_interpreter"] = codeInterpreter.toDictionary()
        }
        return dict
    }
}

// MARK: - FileSearchResources
struct FileSearchResources: Codable {
    let vectorStoreIds: [String]?

    private enum CodingKeys: String, CodingKey {
        case vectorStoreIds = "vector_store_ids"
    }

    func toDictionary() -> [String: Any] {
        return ["vector_store_ids": vectorStoreIds ?? []]
    }
}

// MARK: - CodeInterpreterResources
struct CodeInterpreterResources: Codable {
    let fileIds: [String]?

    private enum CodingKeys: String, CodingKey {
        case fileIds = "file_ids"
    }

    func toDictionary() -> [String: Any] {
        return ["file_ids": fileIds ?? []]
    }
}

// MARK: - FileSearch
struct FileSearch: Codable {
    let max_num_results: Int?
    
    func toFileSearchDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let max_num_results = max_num_results {
            dict["max_num_results"] = max_num_results
        }
        return dict
    }
}

// MARK: - MessageContent
struct MessageContent: Codable, Equatable {
    let type: String
    let text: TextContent?
    let image: ImageContent?

    private enum CodingKeys: String, CodingKey {
        case type, text, image
    }
}


// MARK: - TextContent
struct TextContent: Codable, Equatable {
    let value: String

    private enum CodingKeys: String, CodingKey {
        case value
    }
}

// MARK: - ImageContent
struct ImageContent: Codable, Equatable {
    let url: String

    private enum CodingKeys: String, CodingKey {
        case url
    }
}

// MARK: - TruncationStrategy
struct TruncationStrategy: Decodable, Equatable {
    let type: String
    let last_messages: [String]?

    private enum CodingKeys: String, CodingKey {
        case type, last_messages
    }
}

// MARK: - ExpiresAfter
struct ExpiresAfter: Codable {
    let anchor: String?
    let days: Int?
}

// MARK: - ExpiresAfterType
/// Enum to handle different types of expiration data.
enum ExpiresAfterType: Codable {
    case int(Int)
    case dict(ExpiresAfter)
    case none

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let dictVal = try? container.decode(ExpiresAfter.self) {
            self = .dict(dictVal)
        } else {
            self = .none
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value):
            try container.encode(value)
        case .dict(let value):
            try container.encode(value)
        case .none:
            try container.encodeNil()
        }
    }
}

// MARK: - File
/// Represents a file with metadata and status information.
struct File: Identifiable, Codable {
    let id: String
    let name: String?
    let status: String
    let createdAt: Int
    let bytes: Int?
    let purpose: String?
    let mimeType: String?
    let objectType: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, status, bytes, purpose, mimeType, objectType
        case createdAt = "created_at"
    }
}

// Example JSON decoding
func decodeFile(from jsonData: Data) -> File? {
    let decoder = JSONDecoder()
    do {
        let file = try decoder.decode(File.self, from: jsonData)
        return file
    } catch {
        print("Failed to decode JSON: \(error.localizedDescription)")
        return nil
    }
}

// MARK: - AssistantSettings
struct AssistantSettings: Decodable {
    let id: String
    let object: String
    let created_at: Int
    let name: String
    let description: String?
    let model: String
    let instructions: String?
    let tools: [Tool]
    let top_p: Double
    let temperature: Double
    let tool_resources: ToolResources?
    let metadata: [String: String]?
    let response_format: ResponseFormat?
    let file_ids: [String]? // Added property
}

// MARK: - FileBatch
struct FileBatch: Codable {
    let id: String
}
