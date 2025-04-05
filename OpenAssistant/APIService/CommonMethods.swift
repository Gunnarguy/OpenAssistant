import Foundation

extension OpenAIService {
    func configureRequest(_ request: inout URLRequest, httpMethod: HTTPMethod) {
        request.httpMethod = httpMethod.rawValue
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: HTTPHeaderField.authorization.rawValue)
        request.setValue(ContentType.json.rawValue, forHTTPHeaderField: HTTPHeaderField.contentType.rawValue)
        request.setValue("assistants=v2", forHTTPHeaderField: HTTPHeaderField.openAIBeta.rawValue)
    }

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

    func addCommonHeaders(to request: inout URLRequest) {
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
    }
}
