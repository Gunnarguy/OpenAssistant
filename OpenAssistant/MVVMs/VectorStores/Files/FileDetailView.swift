import Combine
import Foundation
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

    /// The main section displaying various file attributes.
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

            // Conditionally display the last error message if it exists.
            if let error = file.lastError {
                errorDetailRow(title: "Last Error", error: error.message)  // Pass error.message string
            }

            // Section displaying chunking strategy details.
            chunkingStrategySection
        }
    }

    /// An overlay view for displaying toast notifications.
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
    /// A dedicated section to display chunking strategy information if available.
    private var chunkingStrategySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chunking Strategy")
                .font(.headline)
                .foregroundColor(.primary)

            if let chunkingStrategy = file.chunkingStrategy {
                detailRow(title: "Type", value: chunkingStrategy.type)

                if let staticStrategy = chunkingStrategy.staticStrategy {
                    detailRow(
                        title: "Max Chunk Size",
                        value: "\(staticStrategy.maxChunkSizeTokens) tokens")
                    detailRow(
                        title: "Chunk Overlap", value: "\(staticStrategy.chunkOverlapTokens) tokens"
                    )
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
    /// Formats a Unix timestamp into a human-readable date and time string.
    /// - Parameter timestamp: The Unix timestamp (seconds since 1970).
    /// - Returns: A formatted date string (e.g., "May 5, 2025, 10:30 AM").
    private func formattedDate(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Formats a byte count into a human-readable string (KB, MB, GB).
    /// - Parameter bytes: The number of bytes.
    /// - Returns: A formatted size string (e.g., "1.23 MB").
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

    /// Determines the color associated with a given file status string.
    /// - Parameter status: The status string (e.g., "completed", "failed").
    /// - Returns: A SwiftUI Color corresponding to the status.
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

    /// Copies the given text to the system clipboard and shows a confirmation toast.
    /// - Parameters:
    ///   - text: The string to copy.
    ///   - label: A descriptive label for the copied item (e.g., "File ID").
    private func copyToClipboard(_ text: String, label: String) {
        #if canImport(AppKit)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #endif
        toastMessage = "\(label) copied!"
        showCopyToast = true

        // Hide the toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopyToast = false
        }
    }

    // MARK: - Reusable Views
    /// A reusable view component for displaying a key-value pair.
    /// - Parameters:
    ///   - title: The label/key for the detail.
    ///   - value: The value to display.
    /// - Returns: A view displaying the title and value.
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

    /// A reusable view component similar to `detailRow` but adds a copy button.
    /// - Parameters:
    ///   - title: The label/key for the detail.
    ///   - value: The value to display (often an ID).
    ///   - action: The closure to execute when the copy button is tapped.
    /// - Returns: A view displaying the title, value, and a copy button.
    private func copyableDetailRow(title: String, value: String, action: @escaping () -> Void)
        -> some View
    {
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

    /// A reusable view component specifically for displaying error messages.
    /// - Parameters:
    ///   - title: The label for the error (e.g., "Last Error").
    ///   - error: The error message string to display.
    /// - Returns: A view displaying the error title and message with distinct styling.
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
