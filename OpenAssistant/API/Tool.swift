import Foundation

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
