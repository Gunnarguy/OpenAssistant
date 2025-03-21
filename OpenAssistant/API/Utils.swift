import Foundation
import Combine

/// Contains utility functions and extensions for the OpenAIService
enum OpenAIUtils {
    
    /// Convenience function to create standard NSErrors for the API
    static func createError(message: String, code: Int = -1) -> Error {
        return NSError(domain: "com.openassistant.api", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
    
    /// Helper to standardize URL creation
    static func createURL(baseURL: URL, endpoint: String) -> URL? {
        return URL(string: "\(baseURL)\(endpoint)")
    }
    
    /// Converts snake_case API response keys to camelCase for Swift
    static func convertSnakeCaseToCamelCase(_ string: String) -> String {
        let components = string.components(separatedBy: "_")
        guard let first = components.first else { return string }
        
        let camelCaseString = components.dropFirst().reduce(first) { result, component in
            return result + component.capitalized
        }
        return camelCaseString
    }
}

// MARK: - Publisher Extensions
extension Publisher {
    /// Standardizes error logging and main thread dispatching for all publishers
    func handleOpenAIResponse<T>() -> AnyPublisher<T, Error> where Output == T {
        return self
            .map { response in
                print("Received response: \(response)")
                return response
            }
            .mapError { error in
                print("Error: \(error.localizedDescription)")
                return error
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - Error Handling Extensions
extension Error {
    /// Converts any error to an OpenAIServiceError
    func toOpenAIServiceError(data: Data? = nil, response: URLResponse? = nil) -> OpenAIServiceError {
        if let error = self as? OpenAIServiceError {
            return error
        }
        
        if let urlError = self as? URLError {
            return .networkError(urlError)
        }
        
        return .custom(self.localizedDescription)
    }
}
