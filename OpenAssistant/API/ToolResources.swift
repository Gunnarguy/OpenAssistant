import Foundation

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
