import Foundation
import Combine
import SwiftUI

/// Represents the usage statistics for a particular operation.
struct Usage: Codable, Equatable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }

    init(promptTokens: Int? = nil, completionTokens: Int? = nil, totalTokens: Int? = nil) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

// MARK: - TruncationStrategy
struct TruncationStrategy: Decodable, Equatable {
    let type: String
    let last_messages: [String]?
}

// MARK: - ExpiresAfter
struct ExpiresAfter: Codable {
    let anchor: String?
    let days: Int?
}

// MARK: - ExpiresAfterType
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

// MARK: - ModelResponse
/// A response structure that contains an array of models.
struct ModelResponse: Codable {
    let data: [Model]
}

// MARK: - Model
/// A structure representing a model with its associated metadata.
struct Model: Codable {
    let id: String
    let created: Int
    let ownedBy: String

}
