import Foundation
import Combine
import SwiftUI

// MARK: - OpenAIServiceError

enum OpenAIServiceError: Error, Equatable {
    case networkError(Error)
    case apiKeyMissing
    case invalidResponse(URLResponse)
    case noData
    case decodingError(Data, Error)
    case rateLimitExceeded(Int)
    case internalServerError
    case unknownError
    case invalidRequest
    case custom(String)
    
    static func ==(lhs: OpenAIServiceError, rhs: OpenAIServiceError) -> Bool {
        return lhs.localizedDescription == rhs.localizedDescription
    }
}

// MARK: - IdentifiableError

struct IdentifiableError: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - APIError

struct APIError: Decodable, Equatable {
    let error: APIErrorDetail

    private enum CodingKeys: String, CodingKey {
        case error
    }
}

struct APIErrorDetail: Decodable, Equatable {
    let message: String
    let type: String
    let param: String?
    let code: String?

    private enum CodingKeys: String, CodingKey {
        case message, type, param, code
    }
}

// MARK: - VectorStoreError

enum VectorStoreError: Error {
    case missingAPIKey
    case serviceNotInitialized
    case fetchFailed(String)
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing API Key"
        case .serviceNotInitialized:
            return "Service not initialized"
        case .fetchFailed(let message):
            return message
        case .uploadFailed(let message):
            return message
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
        print("Error: \(errorDescription ?? "Unknown error")")
    }
}

// MARK: - ErrorHandler

class ErrorHandler: ObservableObject {
    @Published var errorMessage: String?

    func handleError(_ message: String) {
        errorMessage = message
        print("Error: \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.errorMessage = nil
        }
    }
}
