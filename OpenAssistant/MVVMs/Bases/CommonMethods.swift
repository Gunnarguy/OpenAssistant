import Foundation

// MARK: - OpenAIService Extensions
extension OpenAIService {
    /// Configures a URL request with common headers for OpenAI API
    func configureRequest(_ request: inout URLRequest, httpMethod: HTTPMethod) {
        request.httpMethod = httpMethod.rawValue
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: HTTPHeaderField.authorization.rawValue)
        request.setValue(ContentType.json.rawValue, forHTTPHeaderField: HTTPHeaderField.contentType.rawValue)
        request.setValue("assistants=v2", forHTTPHeaderField: HTTPHeaderField.openAIBeta.rawValue)
    }

    /// Creates a URL request for the specified endpoint
    func makeRequest(endpoint: String, httpMethod: HTTPMethod = .get, body: [String: Any]? = nil) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            logError("Invalid URL for endpoint: \(endpoint)")
            return nil
        }
        
        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: httpMethod)
        
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                logError("Error serializing JSON body: \(error.localizedDescription)")
                return nil
            }
        }
        return request
    }

    /// Adds common headers to a URLRequest for OpenAI API
    /// - Parameters:
    ///   - request: The URLRequest to modify
    ///   - contentType: Optional content type to specify
    func addCommonHeaders(to request: inout URLRequest, contentType: String? = nil) {
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        
        if let contentType = contentType {
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }
    }
}
