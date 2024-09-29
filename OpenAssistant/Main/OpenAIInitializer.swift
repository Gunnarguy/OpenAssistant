import Foundation
import Combine
import SwiftUI

/// A class responsible for initializing the OpenAIService with the provided API key.
class OpenAIServiceInitializer {
    
    /// The shared instance of OpenAIService.
    private static var sharedService: OpenAIService?
    
    /// Initializes the OpenAIService with the provided API key.
    /// - Parameter apiKey: The API key for authenticating with the OpenAI service.
    /// - Returns: An instance of OpenAIService if the API key is valid, otherwise nil.
    static func initialize(apiKey: String) -> OpenAIService? {
        guard !apiKey.isEmpty else {
            print("Error: API key is empty.")
            return nil
        }
        
        if let service = sharedService {
            return service
        }
        
        let service = OpenAIService(apiKey: apiKey)
        sharedService = service
        return service
    }
}
