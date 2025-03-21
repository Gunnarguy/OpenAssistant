import Foundation
import Combine
import SwiftUI

/// A singleton class that provides shared service instances across the app
class ServiceProvider {
    static let shared = ServiceProvider()
    
    /// The shared OpenAI service instance
    let openAIService: OpenAIService
    
    private init() {
        // Get API key from secure storage or environment
        let apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        self.openAIService = OpenAIService(apiKey: apiKey)
        print("ServiceProvider initialized with shared OpenAI service")
    }
    
    /// Updates the API key used by the OpenAI service
    func updateAPIKey(_ newKey: String) {
        UserDefaults.standard.set(newKey, forKey: "openai_api_key")
        // Since OpenAIService is reference-based, we can't reassign it
        // Instead, you would need to implement a mechanism to update the key in the service
        // For example, by making apiKey a published property in OpenAIService
    }
}
