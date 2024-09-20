import Foundation
import Combine
import SwiftUI

enum OpenAIServiceError: Error {
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

enum VectorStoreError: Error {
    case missingAPIKey
    case serviceNotInitialized
    case fetchFailed(String)
    case uploadFailed(String) // Added this case

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing API Key"
        case .serviceNotInitialized:
            return "Service not initialized"
        case .fetchFailed(let message):
            return message
        case .uploadFailed(let message):
            return message // Add this to satisfy exhaustiveness
        }
    }
}

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
            print("Error: File selection failed.")
        case .fileReadFailed(let fileName):
            print("Error: Failed to read file '\(fileName)'.")
        case .uploadFailed(let reason):
            print("Error: File upload failed. Reason: \(reason)")
        case .batchCreationFailed(let reason):
            print("Error: Batch creation failed. Reason: \(reason)")
        case .noFilesSelected:
            print("Error: No files were selected.")
        }
    }
}

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
