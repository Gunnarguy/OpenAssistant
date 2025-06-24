import AVFoundation  // For audio/video processing
import Foundation
import UIKit  // For image conversion
import UniformTypeIdentifiers  // For MIME types

// MARK: - File Processing Logic

// Custom errors for file processing
enum FileProcessingError: Error, LocalizedError {
    case unsupportedFileType(String)
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let type):
            return "File type '\(type)' is not supported and no conversion is available."
        case .conversionFailed(let reason):
            return "File conversion failed: \(reason)"
        }
    }
}

// A protocol for defining file conversion strategies.
// This allows for easy extension with new conversion types.
protocol FileConversionStrategy {
    /// Converts file data into a supported format.
    /// - Parameter data: The original file data.
    /// - Returns: A tuple containing the converted data and the new file extension.
    func convert(data: Data) throws -> (newData: Data, newExtension: String)
}

// MARK: - Conversion Strategies

/// Converts HEIC images to JPEG format.
class HEICToJPEGStrategy: FileConversionStrategy {
    func convert(data: Data) throws -> (newData: Data, newExtension: String) {
        guard let image = UIImage(data: data),
            let jpegData = image.jpegData(compressionQuality: 0.8)
        else {
            throw FileProcessingError.conversionFailed("Failed to convert HEIC to JPEG.")
        }
        return (jpegData, "jpg")
    }
}

/// Converts RTF documents to plain text.
class RTFToTXTStrategy: FileConversionStrategy {
    func convert(data: Data) throws -> (newData: Data, newExtension: String) {
        do {
            let attributedString = try NSAttributedString(
                data: data, options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil)
            guard let txtData = attributedString.string.data(using: .utf8) else {
                throw FileProcessingError.conversionFailed("Failed to convert RTF to TXT.")
            }
            return (txtData, "txt")
        } catch {
            throw FileProcessingError.conversionFailed(
                "Error decoding RTF: \(error.localizedDescription)")
        }
    }
}

/// A placeholder strategy for transcribing audio files to text.
/// In a real implementation, this would integrate with a speech-to-text service like OpenAI's Whisper API.
class AudioTranscriptionStrategy: FileConversionStrategy {
    func convert(data: Data) throws -> (newData: Data, newExtension: String) {
        // This is a placeholder. A real implementation would involve a network request
        // to a transcription service. For now, we return placeholder text.
        let transcribedText =
            "[Transcription placeholder: Audio content would be converted to text here.]"
        guard let textData = transcribedText.data(using: .utf8) else {
            throw FileProcessingError.conversionFailed(
                "Failed to create data from transcribed text.")
        }
        return (textData, "txt")
    }
}

/// Handles the logic of checking file type support and applying conversions.
class FileProcessor {
    // List of file extensions directly supported by the OpenAI Assistants API.
    // See: https://platform.openai.com/docs/assistants/tools/file-search/supported-files
    private let supportedExtensions: Set<String> = [
        "c", "cpp", "csv", "docx", "html", "java", "json", "md", "pdf", "php", "pptx", "py", "rb",
        "tex", "txt", "xml",
        "jpeg", "jpg", "png", "gif",
    ]

    // Maps unsupported file extensions to their corresponding conversion strategy.
    private let conversionStrategies: [String: FileConversionStrategy] = [
        "heic": HEICToJPEGStrategy(),
        "rtf": RTFToTXTStrategy(),
        // Common audio and video formats that can be transcribed
        "m4a": AudioTranscriptionStrategy(),
        "mp3": AudioTranscriptionStrategy(),
        "wav": AudioTranscriptionStrategy(),
        "mp4": AudioTranscriptionStrategy(),
        "mov": AudioTranscriptionStrategy(),
    ]

    /// Processes a file, converting it if necessary to a supported format.
    /// - Parameters:
    ///   - fileData: The raw data of the file.
    ///   - fileName: The original name of the file, including its extension.
    /// - Returns: A tuple with the processed data and a potentially new file name.
    func processFile(fileData: Data, fileName: String) async throws -> (
        processedData: Data, processedFileName: String
    ) {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()

        // If the file type is directly supported, return it as is.
        if supportedExtensions.contains(fileExtension) {
            return (fileData, fileName)
        }

        // If a specific conversion strategy exists for the file type, use it.
        if let strategy = conversionStrategies[fileExtension] {
            do {
                let (newData, newExtension) = try strategy.convert(data: fileData)
                let newFileName = (fileName as NSString).deletingPathExtension + "." + newExtension
                return (newData, newFileName)
            } catch {
                throw FileProcessingError.conversionFailed(
                    "Conversion failed for \(fileName): \(error.localizedDescription)")
            }
        }

        // As a fallback for unknown file types, try to interpret them as plain text.
        if let stringContent = String(data: fileData, encoding: .utf8)
            ?? String(data: fileData, encoding: .ascii)
        {
            if !stringContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let newFileName = (fileName as NSString).deletingPathExtension + ".txt"
                guard let textData = stringContent.data(using: .utf8) else {
                    throw FileProcessingError.conversionFailed(
                        "Could not convert extracted text to Data.")
                }
                return (textData, newFileName)
            }
        }

        // If no conversion is possible, throw an error.
        throw FileProcessingError.unsupportedFileType(fileExtension)
    }
}

// MARK: - File Upload Service

class FileUploadService {
    let baseURL: String
    let apiKey: String
    let session: URLSession
    private let fileProcessor: FileProcessor

    init(
        baseURL: String = "https://api.openai.com/v1", apiKey: String, session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
        self.fileProcessor = FileProcessor()
    }

    func addCommonHeaders(to request: inout URLRequest) {
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
    }

    // Uploads a file to OpenAI, converting it if necessary, and returns the file ID
    func uploadFile(fileData: Data, fileName: String) async throws -> String {
        // First, process the file to handle any necessary conversions for unsupported types.
        let (processedData, processedFileName) = try await fileProcessor.processFile(
            fileData: fileData, fileName: fileName)

        let url = URL(string: "\(baseURL)/files")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)

        let boundary = UUID().uuidString
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Dynamically determine the MIME type from the processed file's extension.
        let pathExtension = (processedFileName as NSString).pathExtension
        let mimeType =
            UTType(filenameExtension: pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"

        // Construct the multipart form data body
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
        body.append("assistants\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(processedFileName)\"\r\n"
                .data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(processedData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            if let httpResponse = response as? HTTPURLResponse {
                let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                print("HTTP Error: \(httpResponse.statusCode), Body: \(responseBody)")
            }
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let fileId = json?["id"] as? String else {
            throw NSError(
                domain: "", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "File ID not found in response"])
        }

        return fileId
    }

    // Creates a vector store and returns its ID
    func createVectorStore(name: String) async throws -> String {
        let url = URL(string: "\(baseURL)/vector_stores")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let vectorStoreId = json?["id"] as? String else {
            throw NSError(
                domain: "", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Vector Store ID not found in response"])
        }

        return vectorStoreId
    }

    // Associates a file with a vector store
    func addFileToVectorStore(vectorStoreId: String, fileId: String) async throws {
        let url = URL(string: baseURL)!.appendingPathComponent(
            "vector_stores/\(vectorStoreId)/files")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addCommonHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["file_id": fileId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
    }
}
