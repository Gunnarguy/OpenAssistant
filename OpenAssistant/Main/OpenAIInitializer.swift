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
        
        let service = OpenAIService(apiKey: apiKey)
        sharedService = service
        return service
    }
    
    /// Re-initializes the OpenAIService with a new API key.
    /// - Parameter apiKey: The new API key for authenticating with the OpenAI service.
    /// - Returns: An instance of OpenAIService if the API key is valid, otherwise nil.
    static func reinitialize(apiKey: String) -> OpenAIService? {
        sharedService = nil
        return initialize(apiKey: apiKey)
    }
}
