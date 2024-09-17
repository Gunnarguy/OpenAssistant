import Foundation
import Combine
import SwiftUI

struct FileDetailView: View {
    let file: VectorStoreFile

    var body: some View {
        List {
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
                    Text("Chunking Strategy: \(chunkingStrategy.type)")
                    if let staticStrategy = chunkingStrategy.staticStrategy {
                        Text("Max Chunk Size Tokens: \(staticStrategy.maxChunkSizeTokens)")
                        Text("Chunk Overlap Tokens: \(staticStrategy.chunkOverlapTokens)")
                    }
                } else {
                    Text("Chunking Strategy: None")
                }
            }
        }
        .navigationTitle(file.object)
        .onAppear {
            print("File data: \(file)")
        }
    }

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
