import Foundation
import Combine
import SwiftUI

extension OpenAIService {
    
    // MARK: - Fetch Assistants
    
    func fetchAssistants(completion: @escaping (Result<[Assistant], OpenAIServiceError>) -> Void) {
        let endpoint = "assistants"
        guard let request = makeRequest(endpoint: endpoint) else {
            completion(.failure(.invalidRequest))
            return
        }
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
        guard let request = makeRequest(endpoint: "assistants/\(assistantId)/settings") else {
            completion(.failure(.invalidRequest))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }
    
    // MARK: - Create Assistant
    func createAssistant(
        model: String,
        name: String? = nil,
        description: String? = nil,
        instructions: String? = nil,
        tools: [[String: Any]]? = nil,
        toolResources: [String: Any]? = nil,
        metadata: [String: String]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        responseFormat: ResponseFormat? = nil,
        completion: @escaping (Result<Assistant, OpenAIServiceError>) -> Void
    ) {
        var body: [String: Any] = ["model": model]

        if let name = name { body["name"] = name }
        if let description = description { body["description"] = description }
        if let instructions = instructions { body["instructions"] = instructions }
        if let tools = tools { body["tools"] = tools }
        if let toolResources = toolResources { body["tool_resources"] = toolResources }
        if let metadata = metadata { body["metadata"] = metadata }
        if let temperature = temperature { body["temperature"] = temperature }
        if let topP = topP { body["top_p"] = topP }
        if let responseFormat = responseFormat { body["response_format"] = responseFormat.toAny() }

        guard let request = makeRequest(endpoint: "assistants", httpMethod: "POST", body: body) else {
            completion(.failure(.invalidRequest))
            return
        }

        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    private func makeRequest(endpoint: String, httpMethod: String, body: [String: Any]) -> URLRequest? {
        guard let url = URL(string: "https://api.openai.com/v1/\(endpoint)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            return nil
        }

        return request
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
        
        
        guard let request = makeRequest(endpoint: "assistants/\(assistantId)", httpMethod: .post, body: body) else {
            completion(.failure(.invalidRequest))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }
    
    // MARK: - Delete Assistant
    
    func deleteAssistant(assistantId: String, completion: @escaping (Result<Void, OpenAIServiceError>) -> Void) {
        guard let request = makeRequest(endpoint: "assistants/\(assistantId)", httpMethod: .delete) else {
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

// MARK: - Tool
struct Tool: Codable {
    var type: String
    var maxNumResults: Int?
    var function: FunctionTool?
    var retrieval: RetrievalTool?

    private enum CodingKeys: String, CodingKey {
        case type
        case maxNumResults = "max_num_results"
        case function
        case retrieval
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let maxNumResults = maxNumResults {
            dict["max_num_results"] = maxNumResults
        }
        if let function = function {
            dict["function"] = function.toDictionary()
        }
        if let retrieval = retrieval {
            dict["retrieval"] = retrieval.toDictionary()
        }
        return dict
    }
}

// MARK: - FunctionTool
struct FunctionTool: Codable {
    var description: String?
    var name: String
    var parameters: [String: Any]?

    private enum CodingKeys: String, CodingKey {
        case description
        case name
        case parameters
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
        try container.encode(name, forKey: .name)
        if let parameters = parameters {
            let data = try JSONSerialization.data(withJSONObject: parameters, options: [])
            let jsonString = String(data: data, encoding: .utf8)
            try container.encode(jsonString, forKey: .parameters)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        name = try container.decode(String.self, forKey: .name)
        if let jsonString = try container.decodeIfPresent(String.self, forKey: .parameters),
           let data = jsonString.data(using: .utf8) {
            parameters = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } else {
            parameters = nil
        }
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["name": name]
        if let description = description {
            dict["description"] = description
        }
        if let parameters = parameters {
            dict["parameters"] = parameters
        }
        return dict
    }
}

// MARK: - RetrievalTool
struct RetrievalTool: Codable {
    var description: String?
    var name: String
    var options: [String: Any]?

    private enum CodingKeys: String, CodingKey {
        case description
        case name
        case options
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
        try container.encode(name, forKey: .name)
        if let options = options {
            let data = try JSONSerialization.data(withJSONObject: options, options: [])
            let jsonString = String(data: data, encoding: .utf8)
            try container.encode(jsonString, forKey: .options)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        name = try container.decode(String.self, forKey: .name)
        if let jsonString = try container.decodeIfPresent(String.self, forKey: .options),
           let data = jsonString.data(using: .utf8) {
            options = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } else {
            options = nil
        }
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["name": name]
        if let description = description {
            dict["description"] = description
        }
        if let options = options {
            dict["options"] = options
        }
        return dict
    }
}

// MARK: - ToolResources
struct ToolResources: Codable {
    var fileSearch: FileSearchResources?
    var codeInterpreter: CodeInterpreterResources?

    private enum CodingKeys: String, CodingKey {
        case fileSearch = "file_search"
        case codeInterpreter = "code_interpreter"
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let fileSearch = fileSearch {
            dict["file_search"] = fileSearch.toDictionary()
        }
        if let codeInterpreter = codeInterpreter {
            dict["code_interpreter"] = codeInterpreter.toDictionary()
        }
        return dict
    }
}

// MARK: - FileSearchResources
struct FileSearchResources: Codable {
    let vectorStoreIds: [String]?

    private enum CodingKeys: String, CodingKey {
        case vectorStoreIds = "vector_store_ids"
    }

    func toDictionary() -> [String: Any] {
        return ["vector_store_ids": vectorStoreIds ?? []]
    }
}

// MARK: - CodeInterpreterResources
struct CodeInterpreterResources: Codable {
    let fileIds: [String]?

    private enum CodingKeys: String, CodingKey {
        case fileIds = "file_ids"
    }

    func toDictionary() -> [String: Any] {
        return ["file_ids": fileIds ?? []]
    }
}
