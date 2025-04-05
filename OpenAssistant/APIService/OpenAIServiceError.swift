import Foundation

/// Error types that can occur when making OpenAI API requests
enum OpenAIServiceError: Error {
    /// Network-related errors
    case networkError(Error)
    
    /// Error when no data is received from the server
    case noData
    
    /// Error when decoding the server response
    case decodingError(Data, Error)
    
    /// Error when the HTTP response is invalid
    case invalidResponse(URLResponse)
    
    /// Error when the request is invalid
    case invalidRequest
    
    /// Error when the OpenAI API rate limit is exceeded
    case rateLimitExceeded(Int)
    
    /// Error when the OpenAI API returns an internal server error
    case internalServerError
    
    /// Error for unknown issues
    case unknownError
    
    /// Custom error with a message
    case custom(String)
    
    /// Error with the full API error object
    case apiError(APIError)
    
    /// User-friendly error message
    var message: String {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noData:
            return "No data received from the server"
        case .decodingError(_, let error):
            return "Error decoding response: \(error.localizedDescription)"
        case .invalidResponse(let response):
            if let httpResponse = response as? HTTPURLResponse {
                return "Invalid response: HTTP \(httpResponse.statusCode)"
            }
            return "Invalid response from server"
        case .invalidRequest:
            return "Invalid request"
        case .rateLimitExceeded(let seconds):
            return "Rate limit exceeded. Try again in \(seconds) seconds."
        case .internalServerError:
            return "OpenAI server error. Try again later."
        case .unknownError:
            return "An unknown error occurred"
        case .custom(let message):
            return message
        case .apiError(let apiError):
            return "API Error: \(apiError.error.message)"
        }
    }
}

/// Structure representing an API error response from OpenAI
struct APIError: Decodable {
    let error: ErrorDetail
    
    struct ErrorDetail: Decodable {
        let message: String
        let type: String?
        let param: String?
        let code: String?
    }
}

/// Structure representing an upload response error
struct UploadResponse: Decodable {
    let fileId: String?
    let error: ErrorDetail?
    
    struct ErrorDetail: Decodable {
        let message: String
        let type: String?
        let param: String?
        let code: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case fileId = "id"
        case error
    }
}
