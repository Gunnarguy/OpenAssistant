import Foundation
import Combine
import SwiftUI

struct ModelResponse: Codable {
    let data: [Model]
}

struct Model: Codable {
    let id: String
    let created: Int
    let owned_by: String
}
