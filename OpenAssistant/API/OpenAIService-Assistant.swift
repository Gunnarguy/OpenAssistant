import Foundation
import Combine
import SwiftUI

extension OpenAIService {
    
    // MARK: - Fetch Assistants
    
    func fetchAssistants(completion: @escaping (Result<[Assistant], OpenAIServiceError>) -> Void) {
        let endpoint = "assistants"
        let request = makeRequest(endpoint: endpoint)
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error) { (result: Result<AssistantsResponse, OpenAIServiceError>) in
                switch result {
                case .success(let response):
                    completion(.success(response.data))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Fetch Assistant Settings
    func fetchAssistantSettings(assistantId: String, completion: @escaping (Result<AssistantSettings, OpenAIServiceError>) -> Void) {
        let request = makeRequest(endpoint: "assistants/\(assistantId)/settings")
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }
    
    // MARK: - Create Assistant
    func createAssistant(model: String, name: String? = nil, description: String? = nil, instructions: String? = nil, tools: [[String: Any]]? = nil, toolResources: [String: Any]? = nil, metadata: [String: String]? = nil, temperature: Double? = nil, topP: Double? = nil, responseFormat: ResponseFormat? = nil, completion: @escaping (Result<Assistant, OpenAIServiceError>) -> Void) {
        var body: [String: Any] = ["model": model]
        
        body["name"] = name
        body["description"] = description
        body["instructions"] = instructions
        body["tools"] = tools
        body["tool_resources"] = toolResources
        body["metadata"] = metadata
        body["temperature"] = temperature
        body["top_p"] = topP
        body["response_format"] = responseFormat?.toAny()
        
        let request = makeRequest(endpoint: "assistants", httpMethod: .post, body: body)
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }
    
    // MARK: - Update Assistant
    func updateAssistant(assistantId: String, model: String? = nil, name: String? = nil, description: String? = nil, instructions: String? = nil, tools: [[String: Any]]? = nil, toolResources: [String: Any]? = nil, metadata: [String: String]? = nil, temperature: Double? = nil, topP: Double? = nil, responseFormat: ResponseFormat? = nil, completion: @escaping (Result<Assistant, OpenAIServiceError>) -> Void) {
        var body: [String: Any] = [:]
        
        body["model"] = model
        body["name"] = name
        body["description"] = description
        body["instructions"] = instructions
        body["tools"] = tools
        body["tool_resources"] = toolResources
        body["metadata"] = metadata
        body["temperature"] = temperature
        body["top_p"] = topP
        body["response_format"] = responseFormat?.toAny()
        
        let request = makeRequest(endpoint: "assistants/\(assistantId)", httpMethod: .post, body: body)
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }
    
    // MARK: - Delete Assistant
    
    func deleteAssistant(assistantId: String, completion: @escaping (Result<Void, OpenAIServiceError>) -> Void) {
        guard let request = makeRequest(endpoint: "assistants/\(assistantId)", httpMethod: "DELETE") else {
            completion(.failure(.invalidRequest))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleDeleteResponse(data, response, error, completion: completion)
        }.resume()
    }
}


// MARK: - Assistant
struct Assistant: Identifiable, Codable, Equatable {
    let id: String
    let object: String
    let created_at: Int
    var name: String
    var description: String?
    var model: String
    var instructions: String?
    var threads: [Thread]?
    var tools: [Tool]
    var top_p: Double
    var temperature: Double
    var tool_resources: ToolResources?
    var metadata: [String: String]?
    var response_format: ResponseFormat?
    var file_ids: [String]?

    static func ==(lhs: Assistant, rhs: Assistant) -> Bool {
        return lhs.id == rhs.id
    }

    private enum CodingKeys: String, CodingKey {
        case id, object, created_at, name, description, model, instructions, tools, top_p, temperature, tool_resources, metadata, response_format, file_ids
    }

    func toAssistantDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "model": model,
            "temperature": temperature,
            "top_p": top_p,
            "instructions": instructions ?? "",
            "metadata": metadata ?? [:],
            "tools": tools.map { $0.toDictionary() }
        ]
        if let toolResources = tool_resources {
            dict["tool_resources"] = toolResources.toDictionary()
        }
        if let responseFormat = response_format {
            dict["response_format"] = responseFormat.toAny()
        }
        if let fileIds = file_ids {
            dict["file_ids"] = fileIds
        }
        return dict
    }
}

// MARK: - AssistantsResponse
struct AssistantsResponse: Decodable, Equatable {
    let object: String
    let data: [Assistant]
    let first_id: String?
    let last_id: String?
    let has_more: Bool
}

// MARK: - AssistantSettings
struct AssistantSettings: Decodable {
    let id: String
    let object: String
    let created_at: Int
    let name: String
    let description: String?
    let model: String
    let instructions: String?
    let tools: [Tool]
    let top_p: Double
    let temperature: Double
    let tool_resources: ToolResources?
    let metadata: [String: String]?
    let response_format: ResponseFormat?
    let file_ids: [String]?
}
