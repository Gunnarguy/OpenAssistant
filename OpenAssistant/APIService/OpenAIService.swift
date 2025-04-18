import Foundation
import Combine
import SwiftUI

class OpenAIService {
    let apiKey: String
    let baseURL = URL(string: "https://api.openai.com/v1/")!
    let session: URLSession
    
    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    internal  enum HTTPHeaderField: String {
        case authorization = "Authorization"
        case contentType = "Content-Type"
        case openAIBeta = "OpenAI-Beta"
    }
    
    internal   enum ContentType: String {
        case json = "application/json"
        case multipartFormData = "multipart/form-data"
    }
    
    internal enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
    
    // MARK: - Request Configuration
    
    /// Creates a URLRequest with common headers.
    func makeRequest(endpoint: String, httpMethod: HTTPMethod = .get, body: [String: Any]? = nil, contentType: ContentType = .json) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            logError("Invalid URL for endpoint: \(endpoint)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        addCommonHeaders(to: &request, contentType: contentType)
        
        if let body = body {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
                request.httpBody = jsonData
                logRequestDetails(request, body: body)
            } catch {
                logError("Failed to serialize request body: \(error.localizedDescription)")
                return nil
            }
        }
        
        return request
    }
    
    /// Adds common headers required for OpenAI requests
    private func addCommonHeaders(to request: inout URLRequest, contentType: ContentType = .json) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: HTTPHeaderField.authorization.rawValue)
        request.setValue(contentType.rawValue, forHTTPHeaderField: HTTPHeaderField.contentType.rawValue)
        request.setValue("assistants=v2", forHTTPHeaderField: HTTPHeaderField.openAIBeta.rawValue)
    }
    
    // MARK: - HandleResponse
    internal func handleResponse<T: Decodable>(_ data: Data?, _ response: URLResponse?, _ error: Error?, completion: @escaping (Result<T, OpenAIServiceError>) -> Void) {
        handleDataTaskResponse(data: data, response: response, error: error) { (result: Result<T, Error>) in
            switch result {
            case .success(let decodedResponse):
                DispatchQueue.main.async {
                    completion(.success(decodedResponse))
                }
            case .failure(let error):
                let openAIError = self.mapToOpenAIServiceError(error: error, data: data, response: response)
                DispatchQueue.main.async {
                    completion(.failure(openAIError))
                }
            }
        }
    }
    
    // MARK: - Handle HTTP Errors
    func handleHTTPError<T>(_ httpResponse: HTTPURLResponse, data: Data?, completion: @escaping (Result<T, OpenAIServiceError>) -> Void) {
        switch httpResponse.statusCode {
        case 429:
            let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? Int ?? 1
            DispatchQueue.main.async {
                completion(.failure(.rateLimitExceeded(retryAfter)))
            }
        case 500:
            DispatchQueue.main.async {
                completion(.failure(.internalServerError))
            }
        default:
            if let data = data {
                do {
                    let apiError = try JSONDecoder().decode(APIError.self, from: data)
                    print(apiError.error.message)
                } catch {
                    print("Decoding error: \(error)")
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse(httpResponse)))
                }
            }
        }
    }
    
    // MARK: - handleDeleteResponse
    
    func handleDeleteResponse(_ data: Data?, _ response: URLResponse?, _ error: Error?, completion: @escaping (Result<Void, OpenAIServiceError>) -> Void) {
        if let error = error {
            logError("Network error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(.failure(.networkError(error)))
            }
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            logError("Invalid response: \(String(describing: response))")
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse(response!)))
            }
            return
        }
        
        DispatchQueue.main.async {
            completion(.success(()))
        }
    }

    // MARK: - Helper function to map errors
    private func mapToOpenAIServiceError(error: Error, data: Data?, response: URLResponse?) -> OpenAIServiceError {
        if let error = error as? OpenAIServiceError {
            return error
        }
        
        if let urlError = error as? URLError {
            return .networkError(urlError)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return .unknownError
        }
        
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.allHeaderFields["Retry-After"] as? Int ?? 1
            return .rateLimitExceeded(retryAfter)
        } else if httpResponse.statusCode == 500 {
            return .internalServerError
        } else if let data = data {
            do {
                let apiError = try JSONDecoder().decode(APIError.self, from: data)
                return .custom(apiError.error.message) // Changed from .apiError to .custom since apiError case doesn't exist
            } catch {
                return .decodingError(data, error)
            }
        } else {
            return .invalidResponse(httpResponse)
        }
    }
    
    // MARK: - Logging
    internal func logRequestDetails(_ request: URLRequest, body: [String: Any]?) {
        print("Request URL: \(request.url?.absoluteString ?? "No URL")")
        if let body = body {
            print("Request Body: \(body)")
        }
    }
    
    internal func logError(_ message: String) {
        print("Error: \(message)")
    }
    
    internal func logInfo(_ message: String) {
        print("Info: \(message)")
    }
    
    internal func logResponseData(_ data: Data) {
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Response JSON: \(jsonString)")
        } else {
            print("Unable to convert response data to JSON string")
        }
    }
    
    
    // MARK: - Fetch Vector Store Files
    func fetchVectorStoreFiles(vectorStoreId: String) -> Future<[File], Error> {
        return Future { [self] promise in
            guard let url = URL(string: "\(self.baseURL)vector_stores/\(vectorStoreId)/files") else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                    promise(.failure(NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorDescription])))
                    return
                }
                
                guard let data = data else {
                    promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(VectorStoreFilesResponse.self, from: data)
                    promise(.success(response.data))
                } catch {
                    promise(.failure(error))
                }
            }.resume()
        }
    }
    
    // MARK: - Delete File from Vector Store
    func deleteFileFromVectorStore(vectorStoreId: String, fileId: String) -> Future<Void, Error> {
        return Future { [self] promise in
            guard let url = URL(string: "\(self.baseURL)vector_stores/\(vectorStoreId)/files/\(fileId)") else {
                promise(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.addValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
            
            self.session.dataTask(with: request) { _, response, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                    promise(.failure(NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorDescription])))
                    return
                }
                
                promise(.success(()))
            }.resume()
        }
    }
    
    func fetchAvailableModels(completion: @escaping (Result<[String], Error>) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let modelResponse = try JSONDecoder().decode(ModelResponse.self, from: data)
                let modelIds = modelResponse.data.map { $0.id }
                completion(.success(modelIds))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
}
    extension OpenAIService {
        func handleDataTaskResponse<T: Decodable>(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<T, Error>) -> Void) {
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let errorDescription = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                completion(.failure(NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorDescription])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decodedResponse))
            } catch {
                completion(.failure(error))
            }
        }
    }
