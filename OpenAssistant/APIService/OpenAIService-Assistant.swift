import Combine
import Foundation
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
            self.handleResponse(data, response, error) {
                (result: Result<AssistantsResponse, OpenAIServiceError>) in
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
    func fetchAssistantSettings(
        assistantId: String,
        completion: @escaping (Result<AssistantSettings, OpenAIServiceError>) -> Void
    ) {
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
        reasoningEffort: String? = nil,
        responseFormat: ResponseFormat? = nil,
        completion: @escaping (Result<Assistant, OpenAIServiceError>) -> Void
    ) {
        var body: [String: Any] = ["model": model]

        // Add common parameters
        if let name = name { body["name"] = name }
        if let description = description { body["description"] = description }
        if let instructions = instructions { body["instructions"] = instructions }
        if let tools = tools { body["tools"] = tools }
        if let toolResources = toolResources { body["tool_resources"] = toolResources }
        if let metadata = metadata { body["metadata"] = metadata }
        if let responseFormat = responseFormat { body["response_format"] = responseFormat.toAny() }

        // Conditionally add parameters based on model type
        if ModelCapabilities.supportsTempTopPAtAssistantLevel(model) {
            // For models supporting temp/top_p at assistant level
            if let temperature = temperature { body["temperature"] = temperature }
            if let topP = topP { body["top_p"] = topP }
        } else {
            // For reasoning models (o-series)
            if let reasoningEffort = reasoningEffort { body["reasoning_effort"] = reasoningEffort }
        }

        guard let request = makeRequest(endpoint: "assistants", httpMethod: .post, body: body)
        else {
            completion(.failure(.invalidRequest))
            return
        }

        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    // MARK: - Update Assistant
    func updateAssistant(
        assistantId: String,
        model: String? = nil,  // Target model ID (used for capability checks, NOT sent in body)
        name: String? = nil,
        description: String? = nil,
        instructions: String? = nil,
        tools: [[String: Any]]? = nil,
        toolResources: [String: Any]? = nil,
        metadata: [String: String]? = nil,
        temperature: Double? = nil,  // Intended temperature for the target model
        topP: Double? = nil,  // Intended topP for the target model
        reasoningEffort: String? = nil,  // Intended reasoning effort for the target model
        responseFormat: ResponseFormat? = nil,
        completion: @escaping (Result<Assistant, OpenAIServiceError>) -> Void
    ) {
        // Ensure the target model is specified for parameter validation, even if not sent.
        guard let targetModelId = model else {
            print(
                "ERROR: Target model must be provided locally to check capabilities when updating assistant parameters."
            )
            completion(.failure(.invalidRequest))
            return
        }

        // 1. Start with an EMPTY dictionary. Only include parameters that are actually being updated.
        var updateBody: [String: Any] = [:]
        if let name = name { updateBody["name"] = name }
        if let description = description { updateBody["description"] = description }
        if let instructions = instructions { updateBody["instructions"] = instructions }
        if let tools = tools { updateBody["tools"] = tools }
        if let toolResources = toolResources { updateBody["tool_resources"] = toolResources }
        if let metadata = metadata { updateBody["metadata"] = metadata }

        // 2. Conditionally add supported generation parameters based ONLY on model capabilities and non-nil values
        //    These parameters *can* be updated if the model supports them.
        if ModelCapabilities.supportsTempTopPAtAssistantLevel(targetModelId) {
            // Non-reasoning model: Add temp, top_p, response_format if provided for update
            if let temp = temperature { updateBody["temperature"] = temp }
            if let top = topP { updateBody["top_p"] = top }
            if let format = responseFormat { updateBody["response_format"] = format.toAny() }
            print(
                " -> Including temp/top_p/response_format (if provided) for update check based on model \(targetModelId)"
            )
            print(" -> Excluding reasoning_effort for update check based on model \(targetModelId)")
        } else {
            // Reasoning model (o-series): Add reasoning_effort if provided for update
            if let effort = reasoningEffort { updateBody["reasoning_effort"] = effort }
            print(
                " -> Including reasoning_effort (if provided) for update check based on model \(targetModelId)"
            )
            print(
                " -> Excluding temp/top_p/response_format for update check based on model \(targetModelId)"
            )
        }

        // IMPORTANT: The 'model' parameter IS allowed in the update request body according to v2 docs.
        // However, based on testing, the API might ignore this field or error out when changing model families (e.g., GPT-4 to O-series).
        // We will include it as per docs, but be aware it might not change the model.
        if let targetModelId = model {
            updateBody["model"] = targetModelId
        }

        // Log the final dictionary *after* any potential removals and *before* serialization
        print("Final body dictionary for UPDATE before serialization: \(updateBody)")
        print("Keys in updateBody before serialization: \(updateBody.keys)")  // Add this line for explicit key check

        // Log the actual JSON string that will be sent
        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: updateBody, options: [.prettyPrinted])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Serialized JSON Body for UPDATE to be sent:\n\(jsonString)")
            } else {
                print("Serialized JSON Body for UPDATE: <Could not encode as pretty JSON string>")
            }
        } catch {
            print("Error serializing finalBody for UPDATE logging: \(error)")
        }

        // Use the base assistant endpoint for updates (POST method)
        guard
            let request = makeRequest(
                endpoint: "assistants/\(assistantId)", httpMethod: .post, body: updateBody)  // Use the cleaned updateBody
        else {
            completion(.failure(.invalidRequest))
            return
        }

        // ... rest of the function (session.dataTask, handleResponse) ...
        session.dataTask(with: request) { data, response, error in
            // Debug: log HTTP status and response data
            if let httpResponse = response as? HTTPURLResponse {
                print("Update Assistant HTTP status: \(httpResponse.statusCode)")
            }
            if let data = data, let json = String(data: data, encoding: .utf8) {
                print("Update Assistant response data: \(json)")
            }
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    // MARK: - Delete Assistant

    func deleteAssistant(
        assistantId: String, completion: @escaping (Result<Void, OpenAIServiceError>) -> Void
    ) {
        guard let request = makeRequest(endpoint: "assistants/\(assistantId)", httpMethod: .delete)
        else {
            completion(.failure(.invalidRequest))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleDeleteResponse(data, response, error, completion: completion)
        }.resume()
    }

    // New: Fetch Assistant Details
    func fetchAssistantDetails(
        assistantId: String, completion: @escaping (Result<Assistant, OpenAIServiceError>) -> Void
    ) {
        let endpoint = "assistants/\(assistantId)"
        guard let request = makeRequest(endpoint: endpoint) else {
            completion(.failure(.custom("Failed to create request")))
            return
        }
        session.dataTask(with: request) { data, response, error in
            self.handleResponse(data, response, error, completion: completion)
        }.resume()
    }

    // Note: To control generation parameters like temperature/top_p, use the `createResponse` endpoint when sending messages to the assistant, since the Assistants API endpoints don't accept those params.
}

// MARK: - Assistant
struct Assistant: Identifiable, Codable, Equatable {
    let id: String
    let object: String
    let created_at: Int
    var name: String
    var description: String?
    var model: String
    var vectorStoreId: String?
    var instructions: String?
    var threads: [Thread]?
    var tools: [Tool]
    var top_p: Double
    var temperature: Double
    var reasoning_effort: String?  // Optional O-series reasoning effort
    var tool_resources: ToolResources?
    var metadata: [String: String]?
    var response_format: ResponseFormat?
    var file_ids: [String]?
    var iconName: String?  // Added property for icon name

    static func == (lhs: Assistant, rhs: Assistant) -> Bool {
        return lhs.id == rhs.id
    }

    // Explicit CodingKeys including reasoning_effort and iconName
    private enum CodingKeys: String, CodingKey {
        case id, object, created_at, name, description, model, instructions, tools, top_p,
            temperature, reasoning_effort, tool_resources, metadata, response_format, file_ids,
            vectorStoreId, threads, iconName  // Ensure all properties are covered
    }

    // Explicit Decodable initializer
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        object = try container.decode(String.self, forKey: .object)
        created_at = try container.decode(Int.self, forKey: .created_at)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        model = try container.decode(String.self, forKey: .model)
        vectorStoreId = try container.decodeIfPresent(String.self, forKey: .vectorStoreId)  // Decode added property
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions)
        threads = try container.decodeIfPresent([Thread].self, forKey: .threads)  // Decode added property
        tools = try container.decode([Tool].self, forKey: .tools)
        top_p = try container.decode(Double.self, forKey: .top_p)
        temperature = try container.decode(Double.self, forKey: .temperature)
        // Decode reasoning_effort, handling potential absence
        reasoning_effort = try container.decodeIfPresent(String.self, forKey: .reasoning_effort)
        tool_resources = try container.decodeIfPresent(ToolResources.self, forKey: .tool_resources)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
        response_format = try container.decodeIfPresent(
            ResponseFormat.self, forKey: .response_format)
        file_ids = try container.decodeIfPresent([String].self, forKey: .file_ids)
        // Decode iconName, handling potential absence
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
    }

    // Explicit memberwise initializer for direct instantiation (e.g., previews)
    init(
        id: String,
        object: String,
        created_at: Int,
        name: String,
        description: String? = nil,
        model: String,
        vectorStoreId: String? = nil,
        instructions: String? = nil,
        threads: [Thread]? = nil,
        tools: [Tool],
        top_p: Double,
        temperature: Double,
        reasoning_effort: String? = nil,  // Added reasoning_effort
        tool_resources: ToolResources? = nil,
        metadata: [String: String]? = nil,
        response_format: ResponseFormat? = nil,
        file_ids: [String]? = nil,
        iconName: String? = nil  // Added iconName parameter
    ) {
        self.id = id
        self.object = object
        self.created_at = created_at
        self.name = name
        self.description = description
        self.model = model
        self.vectorStoreId = vectorStoreId
        self.instructions = instructions
        self.threads = threads
        self.tools = tools
        self.top_p = top_p
        self.temperature = temperature
        self.reasoning_effort = reasoning_effort  // Assign reasoning_effort
        self.tool_resources = tool_resources
        self.metadata = metadata
        self.response_format = response_format
        self.file_ids = file_ids
        self.iconName = iconName  // Assign iconName
    }

    func toAssistantDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "model": model,
            "temperature": temperature,
            "top_p": top_p,
            "instructions": instructions ?? "",
            "metadata": metadata ?? [:],
            "tools": tools.map { $0.toDictionary() },
        ]
        if let reasoning = reasoning_effort {
            dict["reasoning_effort"] = reasoning
        }
        if let toolResources = tool_resources {
            dict["tool_resources"] = toolResources.toDictionary()
        }
        if let responseFormat = response_format {
            dict["response_format"] = responseFormat.toAny()
        }
        if let fileIds = file_ids {
            dict["file_ids"] = fileIds
        }
        // iconName is not part of the OpenAI API, so it's not included here
        // Ensure vectorStoreId and threads are handled if needed for dictionary conversion,
        // though they might not be part of create/update payloads.
        return dict
    }
}
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
    let reasoning_effort: String?  // Optional O-series reasoning effort
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
            let data = jsonString.data(using: .utf8)
        {
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
            let data = jsonString.data(using: .utf8)
        {
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
    var vectorStoreIds: [String]?

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
