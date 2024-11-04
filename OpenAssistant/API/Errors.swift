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
    case fileSelectionFailed
    case fileReadFailed(String)
    case uploadFailed(String)
    case batchCreationFailed(String)
    case noFilesSelected

    var errorDescription: String? {
        switch self {
        case .fileSelectionFailed:
            return "Failed to select files. Please try again."
        case .fileReadFailed(let fileName):
            return "Failed to read the file: \(fileName). Please check the file and try again."
        case .uploadFailed(let reason):
            return "File upload failed: \(reason)"
        case .batchCreationFailed(let reason):
            return "Failed to create file batch: \(reason)"
        case .noFilesSelected:
            return "No files were selected. Please select files to upload."
        }
    }

    func logError() {
        switch self {
        case .fileSelectionFailed:
            print("File selection failed.")
        case .fileReadFailed(let fileName):
            print("Failed to read file: \(fileName)")
        case .uploadFailed(let reason):
            print("Upload failed with reason: \(reason)")
        case .batchCreationFailed(let reason):
            print("Batch creation failed with reason: \(reason)")
        case .noFilesSelected:
            print("No files selected for upload.")
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
