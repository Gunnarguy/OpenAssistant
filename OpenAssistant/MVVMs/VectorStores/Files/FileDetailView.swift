import Foundation
import Combine
import SwiftUI

struct FileDetailView: View {
    let file: VectorStoreFile
    @State private var isIDCopied = false
    @State private var isVectorStoreIDCopied = false
    @State private var showCopyToast = false
    @State private var toastMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                fileDetailsCard
            }
            .padding()
        }
        .navigationTitle("File Details")
        .overlay(
            // Toast notification for copy actions
            toastOverlay
                .animation(.easeInOut, value: showCopyToast)
        )
    }

    // MARK: - File Details Section
    private var fileDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            fileHeader
            Divider()
            fileDetailsSection
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var fileHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(file.object)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Status: \(file.status)")
                .font(.subheadline)
                .foregroundColor(statusColor(for: file.status))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor(for: file.status).opacity(0.1))
                )
        }
    }
    
    private var fileDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            copyableDetailRow(title: "ID", value: file.id) {
                copyToClipboard(file.id, label: "File ID")
            }
            
            copyableDetailRow(title: "Vector Store ID", value: file.vectorStoreId) {
                copyToClipboard(file.vectorStoreId, label: "Vector Store ID")
            }
            
            detailRow(title: "Object Type", value: file.object)
            detailRow(title: "Size", value: formatBytes(file.usageBytes))
            detailRow(title: "Created", value: formattedDate(from: file.createdAt))
            
            if let error = file.lastError, !error.isEmpty {
                errorDetailRow(title: "Last Error", error: error)
            }
            
            chunkingStrategySection
        }
    }
    
    private var toastOverlay: some View {
        VStack {
            Spacer()
            
            if showCopyToast {
                Text(toastMessage)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.75))
                    )
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Chunking Strategy Section
    private var chunkingStrategySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chunking Strategy")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let chunkingStrategy = file.chunkingStrategy {
                detailRow(title: "Type", value: chunkingStrategy.type)
                
                if let staticStrategy = chunkingStrategy.staticStrategy {
                    detailRow(title: "Max Chunk Size", value: "\(staticStrategy.maxChunkSizeTokens) tokens")
                    detailRow(title: "Chunk Overlap", value: "\(staticStrategy.chunkOverlapTokens) tokens")
                }
            } else {
                Text("No chunking strategy defined")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
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
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "completed", "processed", "success":
            return .green
        case "in_progress", "processing":
            return .blue
        case "failed", "error":
            return .red
        case "cancelled":
            return .orange
        default:
            return .gray
        }
    }
    
    private func copyToClipboard(_ text: String, label: String) {
        UIPasteboard.general.string = text
        toastMessage = "\(label) copied!"
        showCopyToast = true
        
        // Hide the toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopyToast = false
        }
    }

    // MARK: - Reusable Views
    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(title):")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func copyableDetailRow(title: String, value: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            Text("\(title):")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            Button(action: action) {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.blue)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 4)
    }
    
    private func errorDetailRow(title: String, error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title):")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.red)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.1))
                )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}
