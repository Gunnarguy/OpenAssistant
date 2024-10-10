import Foundation

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
