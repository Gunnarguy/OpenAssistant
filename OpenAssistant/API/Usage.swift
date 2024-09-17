import Foundation
import Combine
import SwiftUI

struct Usage: Decodable, Equatable {
    let prompt_tokens: Int?
    let completion_tokens: Int?
    let total_tokens: Int?
}
