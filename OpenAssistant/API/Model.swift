import Foundation

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

    private enum CodingKeys: String, CodingKey {
        case id
        case created
        case ownedBy = "owned_by"
    }
}
