import Foundation

// MARK: - TruncationStrategy
struct TruncationStrategy: Decodable, Equatable {
    let type: String
    let last_messages: [String]?
}
