import Foundation
import Combine
import SwiftUI

// MARK: - ResponseFormat
enum ResponseFormat: Codable {
    case string(String)
    case dictionary([String: String])
    case jsonSchema(JSONSchema)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let dictionaryValue = try? container.decode([String: String].self) {
            self = .dictionary(dictionaryValue)
        } else if let jsonSchemaValue = try? container.decode(JSONSchema.self) {
            self = .jsonSchema(jsonSchemaValue)
        } else {
            throw DecodingError.typeMismatch(ResponseFormat.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String, Dictionary, or JSON Schema"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .jsonSchema(let value):
            try container.encode(value)
        }
    }
    
    func toAny() -> Any {
        switch self {
        case .string(let value):
            return ["type": "text", "value": value]
        case .dictionary(let value):
            let properties = value.mapValues { _ in JSONSchemaProperty(type: "string", description: nil).toDictionary() }
            return ["type": "json_schema", "json_schema": ["type": "object", "properties": properties]]
        case .jsonSchema(let value):
            return ["type": "json_schema", "json_schema": value.toDictionary()]
        }
    }
}

// MARK: - JSONSchema
struct JSONSchema: Codable {
    var type: String
    var properties: [String: JSONSchemaProperty]

    func toDictionary() -> [String: Any] {
        return [
            "type": type,
            "properties": properties.mapValues { $0.toDictionary() }
        ]
    }
}

// MARK: - JSONSchemaProperty
struct JSONSchemaProperty: Codable {
    var type: String
    var description: String?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let description = description {
            dict["description"] = description
        }
        return dict
    }
}

// MARK: - JSONValue
enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case object([String: JSONValue])
    case array([JSONValue])
    case bool(Bool)
    case null
    
    var value: Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .object(let value):
            return value.mapValues { $0.value }
        case .array(let value):
            return value.map { $0.value }
        case .bool(let value):
            return value
        case .null:
            return NSNull()
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid JSON value"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - OpenAIResponse
struct OpenAIResponse: Codable {
    var id: String
    var object: String
    var created_at: Int
    var assistant_id: String?
    var thread_id: String
    var run_id: String?
    var role: String
    var content: [MessageContent]
    var attachments: [String]
    var metadata: [String: String]
}

// Example JSON Schema and Request Body
let jsonSchema = JSONSchema(
    type: "object",
    properties: [
        "key1": JSONSchemaProperty(type: "string", description: "A string key"),
        "key2": JSONSchemaProperty(type: "number", description: "A number key")
    ]
)

let responseFormat = ResponseFormat.jsonSchema(jsonSchema)

let requestBody: [String: Any] = [
    "top_p": 1.0,
    "tools": [],
    "temperature": 0.8,
    "response_format": responseFormat.toAny(),
    "model": "gpt-4o-mini",
    "instructions": "This is a test",
    "name": "Testeroni",
    "metadata": [:],
    "tool_resources": [:]
]

// MARK: - DeleteResponse
struct DeleteResponse: Decodable {
    let id: String
    let object: String
    let deleted: Bool
}
