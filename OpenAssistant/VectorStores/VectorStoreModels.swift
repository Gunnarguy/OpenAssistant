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
