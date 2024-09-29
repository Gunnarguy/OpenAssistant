import Foundation
import Combine
import SwiftUI

class OpenAIServiceInitializer {
    static func initialize(apiKey: String) -> OpenAIService? {
        guard !apiKey.isEmpty else {
            return nil
        }
        return OpenAIService(apiKey: apiKey)
    }
}
