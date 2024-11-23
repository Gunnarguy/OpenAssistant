import Foundation
import Combine

class FileUploadService {
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession
    
    init(baseURL: String = "https://api.openai.com/v1", apiKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }
    
    private func addCommonHeaders(to request: inout URLRequest) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
    }
    
    private func createRequest(
        endpoint: String,
        method: String = "POST",
        contentType: String = "application/json",
        body: [String: Any]? = nil
    ) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            print("Invalid URL for endpoint: \(endpoint)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        addCommonHeaders(to: &request)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        if let body = body, contentType == "application/json" {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            } catch {
                print("Failed to serialize request body: \(error)")
                return nil
            }
        }
        
        return request
    }
    
    private func configureRequest(_ request: inout URLRequest, httpMethod: String) {
        request.httpMethod = httpMethod
        addCommonHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    // MARK: - Upload File
    func uploadFile(fileData: Data, fileName: String) -> AnyPublisher<String, Error> {
        let boundary = UUID().uuidString
        let mimeType = "application/octet-stream"
        let url = "\(baseURL)/files"
        
        guard var request = createRequest(endpoint: "files", method: "POST") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\nassistants\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                guard let fileId = json?["id"] as? String else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "File ID not found"])
                }
                
                return fileId
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Create Vector Store
    func createVectorStore(name: String) -> AnyPublisher<String, Error> {
        guard let url = URL(string: "\(baseURL)/vector_stores") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        configureRequest(&request, httpMethod: "POST")
        
        let body: [String: Any] = ["name": name]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> String in
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let vectorStoreId = json?["id"] as? String else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Vector Store ID not found in response"])
                }
                return vectorStoreId
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Add File to Vector Store
    func addFileToVectorStore(vectorStoreId: String, fileId: String) -> AnyPublisher<Void, Error> {
        let body = ["file_id": fileId]
        guard let request = createRequest(endpoint: "vector_stores/\(vectorStoreId)/files", body: body) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
            }
            .eraseToAnyPublisher()
    }
}
