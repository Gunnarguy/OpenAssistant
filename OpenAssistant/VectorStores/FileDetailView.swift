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
            detailRow(title: "ID", value: file.id)
            detailRow(title: "Object", value: file.object)
            detailRow(title: "Usage Bytes", value: formatBytes(file.usageBytes))
            detailRow(title: "Created At", value: formattedDate(from: file.createdAt))
            detailRow(title: "Vector Store ID", value: file.vectorStoreId)
            detailRow(title: "Status", value: file.status)
            detailRow(title: "Last Error", value: file.lastError ?? "None")
            chunkingStrategySection
        }
    }

    // MARK: - Chunking Strategy Section

    private var chunkingStrategySection: some View {
        Group {
            if let chunkingStrategy = file.chunkingStrategy {
                detailRow(title: "Chunking Strategy", value: chunkingStrategy.type)
                if let staticStrategy = chunkingStrategy.staticStrategy {
                    detailRow(title: "Max Chunk Size Tokens", value: "\(staticStrategy.maxChunkSizeTokens)")
                    detailRow(title: "Chunk Overlap Tokens", value: "\(staticStrategy.chunkOverlapTokens)")
                }
            } else {
                detailRow(title: "Chunking Strategy", value: "None")
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

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text("\(title):")
                .fontWeight(.bold)
            Spacer()
            Text(value)
        }
    }
}
