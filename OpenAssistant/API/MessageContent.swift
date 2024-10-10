import Foundation

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
