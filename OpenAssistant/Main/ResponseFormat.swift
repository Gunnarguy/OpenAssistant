import Combine
import Foundation
import SwiftUI

// MARK: - ResponseFormat
// Defines the possible formats for the assistant's response.
enum ResponseFormat: Codable {
    case string(String)  // Represents simple text or auto mode.
    case dictionary([String: String])  // Represents a request for standard JSON object output.
    case jsonSchema(JSONSchema)  // Represents a request for JSON output conforming to a specific schema.

    // Decodes ResponseFormat from various JSON representations.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // 1. Try decoding as a simple string ("auto" or "text")
        if let stringValue = try? container.decode(String.self) {
            if stringValue == "auto" || stringValue == "text" {
                self = .string(stringValue)  // Store as "auto" or "text"
            } else {
                // Handle unexpected string values if necessary, or throw error
                print(
                    "Warning: Unexpected string value '\(stringValue)' decoded for ResponseFormat. Treating as 'auto'."
                )
                self = .string("auto")  // Default or throw
                // throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unexpected string value for ResponseFormat: \(stringValue)")
            }
            return  // Successfully decoded as string
        }

        // 2. Try decoding as a dictionary to check the "type" field
        // Use a more specific decoding attempt for the dictionary structure
        do {
            let dictionaryContainer = try decoder.container(keyedBy: CodingKeys.self)
            let type = try dictionaryContainer.decode(String.self, forKey: .type)

            switch type {
            case "text":
                // API might return {"type": "text"}
                self = .string("text")
            case "json_object":
                // API returns {"type": "json_object"}
                // Store marker for json_object type
                self = .dictionary(["type": "json_object"])  // Store the type info
            case "json_schema":
                // API returns {"type": "json_schema", "json_schema": {...}}
                // Decode the nested "json_schema" object
                let schema = try dictionaryContainer.decode(JSONSchema.self, forKey: .json_schema)
                self = .jsonSchema(schema)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type, in: dictionaryContainer,
                    debugDescription: "Unknown type value in ResponseFormat dictionary: \(type)")
            }
            return  // Successfully decoded as dictionary
        } catch {
            // If decoding as dictionary fails, proceed to final error
            // This catch block might be too broad, consider more specific error handling if needed
        }

        // 3. If none of the above worked, throw an error
        throw DecodingError.typeMismatch(
            ResponseFormat.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription:
                    "ResponseFormat could not be decoded as String or Dictionary with 'type' field")
        )
    }

    // Define CodingKeys used in the dictionary decoding/encoding path
    private enum CodingKeys: String, CodingKey {
        case type
        case json_schema
    }

    // Encodes ResponseFormat into its JSON representation.
    func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let value):
            // Encode "auto" or "text" appropriately
            if value.lowercased() == "auto" {
                var container = encoder.singleValueContainer()
                try container.encode("auto")  // Encode "auto" as a simple string
            } else {  // Assume "text" or default to text
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("text", forKey: .type)  // Encode as {"type": "text"}
            }
        case .dictionary:
            // Encode dictionary case as {"type": "json_object"}.
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("json_object", forKey: .type)
        case .jsonSchema(let value):
            // Encode JSON schema case with its specific structure.
            // The API expects {"type": "json_schema", "json_schema": {...}}
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("json_schema", forKey: .type)
            // Encode the nested JSONSchema object for the 'json_schema' key
            try container.encode(value, forKey: .json_schema)  // Encode the JSONSchema struct directly
        }
    }

    // Converts ResponseFormat enum to the Any dictionary format expected by the OpenAI API request body.
    func toAny() -> Any {
        switch self {
        case .string(let value):
            // Handle "auto" and "text".
            if value.lowercased() == "auto" {
                // The API accepts the string "auto" directly.
                return "auto"
            } else if value.lowercased() == "text" {
                // The API expects {"type": "text"} for explicit text mode.
                return ["type": "text"]
            } else {
                // If string is something else, default to "auto".
                print(
                    "Warning: Unexpected string value '\(value)' in ResponseFormat. Defaulting to auto."
                )
                return "auto"
            }
        case .dictionary:
            // Represents a request for any valid JSON object output.
            // The API expects {"type": "json_object"}.
            return ["type": "json_object"]
        case .jsonSchema(let value):
            // Represents a request for JSON output conforming to a specific schema.
            // The API expects {"type": "json_schema", "json_schema": {...}}.
            return ["type": "json_schema", "json_schema": value.toDictionary()]
        }
    }
}

// MARK: - JSONSchema
// Represents the structure for defining a JSON schema, matching the API's expectation.
// Make JSONSchema itself Codable to be used in ResponseFormat.encode
struct JSONSchema: Codable {
    var name: String
    var schema: JSONSchemaDefinition  // Nested schema definition
    var description: String?
    var strict: Bool?

    // CodingKeys to map Swift properties to JSON keys
    private enum CodingKeys: String, CodingKey {
        case name, schema, description, strict
    }

    // Converts the JSONSchema struct to a dictionary format for API requests.
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "schema": schema.toDictionary(),  // Embed the nested schema dictionary
        ]
        if let description = description { dict["description"] = description }
        if let strict = strict { dict["strict"] = strict }
        return dict
    }

    // REMOVED explicit encode(to:) - Rely on synthesized version
}

// MARK: - JSONSchemaDefinition
// Represents the actual schema definition (type, properties, etc.) nested within JSONSchema.
// Make JSONSchemaDefinition Codable
struct JSONSchemaDefinition: Codable {
    var type: String  // Typically "object"
    var properties: [String: JSONSchemaProperty]
    // Add 'required' array if needed: var required: [String]?

    // CodingKeys if needed, but default should work if names match JSON
    private enum CodingKeys: String, CodingKey {
        case type, properties  // Add 'required' if using it
    }

    // Converts the JSONSchemaDefinition struct to a dictionary format.
    func toDictionary() -> [String: Any] {
        let dict: [String: Any] = [  // Use let since dict isn't mutated
            "type": type,
            "properties": properties.mapValues { $0.toDictionary() },
        ]
        // Add 'required' if using it: if let required = required { dict["required"] = required }
        return dict
    }

    // REMOVED explicit encode(to:) - Rely on synthesized version
}

// MARK: - JSONSchemaProperty
// Represents a property within a JSON schema's properties.
// Make JSONSchemaProperty Codable
struct JSONSchemaProperty: Codable {
    var type: String  // e.g., "string", "number", "boolean".
    var description: String?  // Optional description of the property.

    // Converts the JSONSchemaProperty struct to a dictionary format.
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let description = description {
            dict["description"] = description
        }
        return dict
    }

    // REMOVED explicit encode(to:) - Rely on synthesized version
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
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath, debugDescription: "Invalid JSON value"))
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

// MARK: - MessageContent
struct MessageContent: Codable, Equatable {
    let type: String
    let text: TextContent?
    let image: ImageContent?
}

// MARK: - TextContent
struct TextContent: Codable, Equatable {
    let value: String
}

// MARK: - ImageContent
struct ImageContent: Codable, Equatable {
    let url: String
}

// Example JSON Schema and Request Body (Updated)
let exampleSchemaDefinition = JSONSchemaDefinition(
    type: "object",
    properties: [
        "key1": JSONSchemaProperty(type: "string", description: "A string key"),
        "key2": JSONSchemaProperty(type: "number", description: "A number key"),
    ]
)

let exampleJsonSchema = JSONSchema(
    name: "ExampleSchema",
    schema: exampleSchemaDefinition,  // Use the nested definition
    description: "An example schema",
    strict: true
)

let responseFormat = ResponseFormat.jsonSchema(exampleJsonSchema)

let requestBody: [String: Any] = [
    "top_p": 1.0,
    "tools": [],
    "temperature": 0.8,
    "response_format": responseFormat.toAny(),
    "model": "gpt-4o-mini",
    "instructions": "This is a test",
    "name": "Testeroni",
    "metadata": [:],
    "tool_resources": [:],
]

// MARK: - DeleteResponse
struct DeleteResponse: Decodable {
    let id: String
    let object: String
    let deleted: Bool
}
