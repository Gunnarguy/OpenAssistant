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
struct ExpiresAfterType: Codable {
    let type: String?
    let staticStrategy: StaticStrategy?
    private enum CodingKeys: String, CodingKey {
        case type, staticStrategy = "static"
    }
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type ?? ""] // Provide a default value if type is nil
        if let staticStrategy = staticStrategy {
            dict["static"] = staticStrategy.toDictionary()
        }
        return dict
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
    let object: String
    let created: Int
    let owned_by: String
}

struct UploadedFile: Codable {
    let id: String
    let object: String
    let bytes: Int
    let createdAt: Int
    let filename: String
    let purpose: String
}
