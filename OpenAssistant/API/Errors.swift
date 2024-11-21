import Foundation
import Combine
import SwiftUI

// MARK: - OpenAIServiceError
extension OpenAIServiceError {
    static func == (lhs: OpenAIServiceError, rhs: OpenAIServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.apiKeyMissing, .apiKeyMissing):
            return true
        case (.invalidResponse(let lhsResponse), .invalidResponse(let rhsResponse)):
            return lhsResponse == rhsResponse
        case (.noData, .noData):
            return true
        case (.responseError(let lhsMessage), .responseError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.decodingError(let lhsData, let lhsError), .decodingError(let rhsData, let rhsError)):
            return lhsData == rhsData && lhsError.localizedDescription == rhsError.localizedDescription
        case (.rateLimitExceeded(let lhsLimit), .rateLimitExceeded(let rhsLimit)):
            return lhsLimit == rhsLimit
        case (.internalServerError, .internalServerError):
            return true
        case (.unknownError, .unknownError):
            return true
        case (.invalidRequest, .invalidRequest):
            return true
        case (.custom(let lhsMessage), .custom(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.authenticationError(let lhsMessage), .authenticationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalidRequestError(let lhsMessage), .invalidRequestError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

enum OpenAIServiceError: Error, Equatable {
    case networkError(Error)
    case apiKeyMissing
    case invalidResponse(URLResponse)
    case noData
    case responseError(String)
    case decodingError(Data, Error)
    case rateLimitExceeded(Int)
    case internalServerError
    case unknownError
    case invalidRequest
    case custom(String)
    case authenticationError(String?)
    case invalidRequestError(String?)
    
    var localizedDescription: String {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiKeyMissing:
            return "API key is missing. Please provide a valid key."
        case .invalidResponse(let response):
            return "Invalid response received: \(response)"
        case .noData:
            return "No data was returned from the server."
        case .responseError(let message):
            return "Response error: \(message)"
        case .decodingError(_, let error):
            return "Failed to decode the response: \(error.localizedDescription)"
        case .rateLimitExceeded(let limit):
            return "Rate limit exceeded. Wait and retry after some time (HTTP \(limit))."
        case .internalServerError:
            return "The server encountered an internal error. Please try again later."
        case .unknownError:
            return "An unknown error occurred."
        case .invalidRequest:
            return "Invalid request. Please check the request parameters."
        case .custom(let message):
            return message
        case .authenticationError(let message):
            return "Authentication error: \(message ?? "Unknown issue with authentication.")"
        case .invalidRequestError(let message):
            return "Invalid request error: \(message ?? "Invalid parameters provided.")"
        }
    }
}

// MARK: - NetworkError
enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "The provided URL is invalid."
        case .invalidResponse:
            return "The response from the server was invalid."
        case .noData:
            return "No data received from the server."
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}

// MARK: - IdentifiableError
struct IdentifiableError: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - APIError
struct APIError: Decodable {
    let error: APIErrorDetail
}

struct APIErrorDetail: Decodable {
    let message: String
    let type: String?
    let param: String?
    let code: String?
    
    init(message: String, type: String? = nil, param: String? = nil, code: String? = nil) {
        self.message = message
        self.type = type
        self.param = param
        self.code = code
    }
}

// MARK: - VectorStoreError
enum VectorStoreError: LocalizedError {
    case serviceNotInitialized
    case fetchFailed(String)
    case unknownError
    case assistantNotSet // Add this case

    var errorDescription: String? {
        switch self {
        case .serviceNotInitialized:
            return "The vector store service is not initialized."
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        case .unknownError:
            return "An unknown error occurred with the vector store."
        case .assistantNotSet: // Add this case
            return "The assistant is not set."
        }
    }
}

// MARK: - FileUploadError
enum FileUploadError: LocalizedError {
    case fileAccessFailed(URL)
    case fileTooLarge(URL, Int)
    case fileEmpty(URL)
    case uploadFailed(URL, String)
    case noFilesSelected
    case fileSelectionFailed(Error)
    case uploadCancelled

    var errorDescription: String? {
        switch self {
        case .fileAccessFailed(let url):
            return "Failed to access file at \(url)."
        case .fileTooLarge(let url, let maxSize):
            return "File \(url.lastPathComponent) is too large. Maximum allowed size is \(maxSize / (1024 * 1024)) MB."
        case .fileEmpty(let url):
            return "File \(url.lastPathComponent) is empty or cannot be read."
        case .uploadFailed(let url, let reason):
            return "Failed to upload file \(url.lastPathComponent): \(reason)"
        case .noFilesSelected:
            return "No files selected."
        case .fileSelectionFailed(let error):
            return "File selection failed: \(error.localizedDescription)"
        case .uploadCancelled:
            return "Upload was canceled."
        }
    }
}

// MARK: - ErrorHandler
class ErrorHandler: ObservableObject {
    @Published var errorMessage: String?

    func handleError(_ error: Error) {
        if let localizedError = error as? LocalizedError, let message = localizedError.errorDescription {
            errorMessage = message
        } else {
            errorMessage = error.localizedDescription
        }
        print("[\(Date())] Error: \(errorMessage ?? "Unknown error")")
        
        // Automatically clears the error message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.errorMessage = nil
        }
    }
}

// MARK: - APIErrorWrapper
enum APIErrorWrapper: Decodable {
    case string(String)
    case detail(APIErrorDetail)
    
    var message: String {
        switch self {
        case .string(let message):
            return message
        case .detail(let detail):
            return detail.message
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringValue = try? container.decode(String.self, forKey: .error) {
            self = .string(stringValue)
        } else if let detailValue = try? container.decode(APIErrorDetail.self, forKey: .error) {
            self = .detail(detailValue)
        } else {
            throw DecodingError.typeMismatch(
                APIErrorWrapper.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected a String or APIErrorDetail for `error`"
                )
            )
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case error
    }
}

// MARK: - ErrorResponse
struct ErrorResponse: Decodable {
    let error: ErrorDetail
}

// MARK: - ErrorDetail
struct ErrorDetail: Decodable {
    let message: String
}

// MARK: - UploadResponse
struct UploadResponse: Decodable {
    let fileId: String?
    let error: APIErrorDetail?
}
