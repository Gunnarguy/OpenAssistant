import Foundation

// MARK: - Vector Store Response
struct VectorStoreResponse: Codable {
    let object: String
    let data: [VectorStore]
}

// MARK: - Vector Store
struct VectorStore: Identifiable, Codable {
    let id: String
    let object: String
    let createdAt: Int
    let name: String?
    let description: String?
    let status: String?
    let usageBytes: Int?
    let lastActiveAt: Int?
    let fileCounts: FileCounts
    
    // Non-codable properties
    var files: [VectorStoreFile] = []
    
    enum CodingKeys: String, CodingKey {
        case id, object, name, description, status
        case createdAt = "created_at"
        case lastActiveAt = "last_active_at"
        case usageBytes = "usage_bytes"
        case fileCounts = "file_counts"
    }
}

// MARK: - File Counts
struct FileCounts: Codable {
    let total: Int
    let completed: Int
    let inProgress: Int
    let failed: Int
    let cancelled: Int
    
    enum CodingKeys: String, CodingKey {
        case total, completed, failed, cancelled
        case inProgress = "in_progress"
    }
}

// MARK: - Vector Store File
struct VectorStoreFile: Identifiable, Codable {
    let id: String
    let object: String
    let usageBytes: Int
    let createdAt: Int
    let vectorStoreId: String
    let status: String
    let lastError: String?
    let chunkingStrategy: ChunkingStrategy?
    
    enum CodingKeys: String, CodingKey {
        case id, object, status
        case usageBytes = "usage_bytes"
        case createdAt = "created_at" 
        case vectorStoreId = "vector_store_id"
        case lastError = "last_error"
        case chunkingStrategy = "chunking_strategy"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        object = try container.decode(String.self, forKey: .object)
        usageBytes = try container.decode(Int.self, forKey: .usageBytes)
        createdAt = try container.decode(Int.self, forKey: .createdAt)
        vectorStoreId = try container.decode(String.self, forKey: .vectorStoreId)
        status = try container.decode(String.self, forKey: .status)
        if let errorString = try? container.decodeIfPresent(String.self, forKey: .lastError) {
            lastError = errorString
        } else if let errorDict = try? container.decodeIfPresent([String: String].self, forKey: .lastError) {
            lastError = errorDict.description
        } else {
            lastError = nil
        }
        chunkingStrategy = try container.decodeIfPresent(ChunkingStrategy.self, forKey: .chunkingStrategy)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(object, forKey: .object)
        try container.encode(usageBytes, forKey: .usageBytes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(vectorStoreId, forKey: .vectorStoreId)
        try container.encode(status, forKey: .status)
        try container.encode(lastError, forKey: .lastError)
        try container.encode(chunkingStrategy, forKey: .chunkingStrategy)
    }
}

// MARK: - Chunking Strategy
struct ChunkingStrategy: Codable {
    let type: String
    let staticStrategy: StaticStrategy?
    
    enum CodingKeys: String, CodingKey {
        case type
        case staticStrategy = "static"
    }
}

// MARK: - Static Strategy
struct StaticStrategy: Codable {
    let maxChunkSizeTokens: Int
    let chunkOverlapTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case maxChunkSizeTokens = "max_chunk_size_tokens"
        case chunkOverlapTokens = "chunk_overlap_tokens"
    }
}

// MARK: - Vector Store File Batch
struct VectorStoreFileBatch: Identifiable, Codable {
    let id: String
    let object: String
    let vectorStoreId: String
    let createdAt: Int
    let fileIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, object
        case vectorStoreId = "vector_store_id"
        case createdAt = "created_at"
        case fileIds = "file_ids"
    }
}

// MARK: - File Model (Raw API response model)
struct File: Identifiable, Codable {
    let id: String
    let object: String?
    let bytes: Int?
    let createdAt: Int
    let filename: String?
    let purpose: String?
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case id, object, bytes, filename, purpose, status
        case createdAt = "created_at"
    }
}
