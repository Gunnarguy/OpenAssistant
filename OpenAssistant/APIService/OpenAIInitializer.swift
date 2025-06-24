import Foundation
import Combine
import SwiftUI

/// A class responsible for initializing the OpenAIService with the provided API key.
final class OpenAIServiceInitializer {
    // MARK: - Properties
    private static var sharedService: OpenAIService?
    private static let lock = NSLock()
    
    // MARK: - Initialization
    /// Initializes the OpenAIService with the provided API key.
    /// - Parameter apiKey: The API key for authenticating with the OpenAI service.
    /// - Returns: An instance of OpenAIService if the API key is valid, otherwise nil.
    static func initialize(apiKey: String) -> OpenAIService? {
        guard !apiKey.isEmpty else {
            logDebug("Error: API key is empty.")
            return nil
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        // Only create a new instance if needed
        if sharedService == nil || sharedService?.apiKey != apiKey {
            sharedService = OpenAIService(apiKey: apiKey)
            logDebug("OpenAIService initialized with new API key")
        } else {
            logDebug("Using existing OpenAIService instance")
        }
        
        return sharedService
    }
    
    // MARK: - Logging
    private static func logDebug(_ message: String) {
        #if DEBUG
        print("OpenAIServiceInitializer: \(message)")
        #endif
    }
}

// MARK: - APIs for backward compatibility
extension OpenAIServiceInitializer {
    /// Re-initializes the OpenAIService with a new API key.
    /// - Parameter apiKey: The new API key for authenticating with the OpenAI service.
    /// - Returns: An instance of OpenAIService if the API key is valid, otherwise nil.
    @available(*, deprecated, message: "Use initialize() instead")
    static func reinitialize(apiKey: String) -> OpenAIService? {
        return initialize(apiKey: apiKey)
    }
}
