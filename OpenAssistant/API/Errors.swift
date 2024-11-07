import Foundation
import Combine
import SwiftUI

// MARK: - OpenAIServiceError
extension OpenAIServiceError {
    init(apiError: APIErrorDetail) {
        switch apiError.code {
        case "rate_limit_exceeded":
            self = .rateLimitExceeded(429)
        case "authentication_error":
            self = .authenticationError(apiError.message)
        case "invalid_request_error":
            self = .invalidRequestError(apiError.message)
        default:
            self = .custom(apiError.message)
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
    
    static func ==(lhs: OpenAIServiceError, rhs: OpenAIServiceError) -> Bool {
        return lhs.localizedDescription == rhs.localizedDescription
    }
}

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError(Error)
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
    
    var errorDescription: String? {
        switch self {
        case .serviceNotInitialized:
            return "The service is not initialized."
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        case .unknownError:
            return "An unknown error occurred."
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = try container.decode(ErrorDetail.self, forKey: .error)
    }
    
    private enum CodingKeys: String, CodingKey {
        case error
    }
}

// MARK: - ErrorDetail
struct ErrorDetail: Decodable {
    let message: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(String.self, forKey: .message)
    }
    
    private enum CodingKeys: String, CodingKey {
        case message
    }
}

// MARK: - UploadResponse
struct UploadResponse: Decodable {
    let fileId: String?
    let error: APIErrorDetail?
}
