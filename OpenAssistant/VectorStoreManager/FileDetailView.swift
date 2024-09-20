import Foundation
import Combine
import SwiftUI

struct FileDetailView: View {
    let file: VectorStoreFile

    var body: some View {
        List {
            fileDetailsSection
        }
        .navigationTitle(file.object)
        .onAppear {
            print("File data: \(file)")
        }
    }

    // MARK: - File Details Section

    private var fileDetailsSection: some View {
        Section(header: Text("File Details")) {
            Text("ID: \(file.id)")
            Text("Object: \(file.object)")
            Text("Usage Bytes: \(formatBytes(file.usageBytes))")
            Text("Created At: \(formattedDate(from: file.createdAt))")
            Text("Vector Store ID: \(file.vectorStoreId)")
            Text("Status: \(file.status)")
            if let lastError = file.lastError {
                Text("Last Error: \(lastError)")
            } else {
                Text("Last Error: None")
            }
            if let chunkingStrategy = file.chunkingStrategy {
                chunkingStrategyDetails(chunkingStrategy)
            } else {
                Text("Chunking Strategy: None")
            }
        }
    }

    // MARK: - Chunking Strategy Details

    private func chunkingStrategyDetails(_ chunkingStrategy: ChunkingStrategy) -> some View {
        Group {
            Text("Chunking Strategy: \(chunkingStrategy.type)")
            if let staticStrategy = chunkingStrategy.staticStrategy {
                Text("Max Chunk Size Tokens: \(staticStrategy.maxChunkSizeTokens)")
                Text("Chunk Overlap Tokens: \(staticStrategy.chunkOverlapTokens)")
            }
        }
    }

    // MARK: - Helper Methods

    private func formattedDate(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.2f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.2f KB", kb)
        } else {
            return "\(bytes) bytes"
        }
    }
}