import Combine
import SwiftUI

// MARK: - Vector Store Management View
/// A view section for managing the association of a Vector Store with an Assistant for File Search.
struct VectorStoreManagementView: View {
    /// The ViewModel managing the Assistant details and API calls.
    @ObservedObject var viewModel: AssistantDetailViewModel
    /// Optional details of the currently associated primary vector store.
    var vectorStore: VectorStore?
    /// The ViewModel managing Vector Store listing and creation.
    @ObservedObject var vectorStoreManagerViewModel: VectorStoreManagerViewModel
    /// Binding to control navigation to the Vector Store detail view.
    @Binding var showVectorStoreDetail: Bool
    /// Binding for the name input when creating a new Vector Store.
    @Binding var vectorStoreName: String
    /// Callback function to trigger the creation of a new Vector Store.
    var onCreateVectorStore: () -> Void

    /// State for the text field used for manual association by ID.
    @State private var vectorStoreIdToAssociate: String = ""
    /// State to control the visibility of the create/associate options.
    @State private var showAssociationOptions = false

    /// Computed property to get the ID of the primary associated vector store, if any.
    private var primaryVectorStoreId: String? {
        viewModel.assistant.tool_resources?.fileSearch?.vectorStoreIds?.first
    }

    var body: some View {
        Section(header: Label("File Search Vector Store", systemImage: "folder.fill")) {

            // --- Display Current Association ---
            VStack(alignment: .leading, spacing: 10) {
                if let currentId = primaryVectorStoreId {
                    Text("Currently Associated Store").font(.headline)
                    if let store = vectorStore, store.id == currentId {
                        // Display details if the VectorStore object is loaded.
                        InfoRow(label: "Name", value: store.name ?? "Unnamed", icon: "tag")
                        InfoRow(label: "ID", value: store.id, icon: "number", truncate: .middle)
                        InfoRow(
                            label: "Created", value: formattedDate(from: store.createdAt),
                            icon: "calendar")

                        // Actions for the current store
                        HStack {
                            // Button to navigate to the Vector Store's file details.
                            Button {
                                showVectorStoreDetail = true
                            } label: {
                                Label("View Files", systemImage: "doc.richtext")
                            }
                            .buttonStyle(.bordered).tint(.accentColor)

                            Spacer()  // Pushes buttons apart

                            // Button to remove the association with this Vector Store.
                            Button(role: .destructive) {
                                viewModel.deleteVectorStoreId(currentId)
                            } label: {
                                Label("Remove", systemImage: "xmark.bin")
                            }
                            .buttonStyle(.bordered).tint(.red)
                        }
                        .padding(.top, 5)

                    } else {
                        // Fallback: Show only the ID if the VectorStore object isn't loaded yet.
                        InfoRow(label: "ID", value: currentId, icon: "number", truncate: .middle)
                        Text("Loading details...")
                            .font(.caption).foregroundColor(.secondary)
                        // Button to remove association even if details aren't loaded.
                        Button(role: .destructive) {
                            viewModel.deleteVectorStoreId(currentId)
                        } label: {
                            Label("Remove Association", systemImage: "xmark.bin")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).tint(.red)
                        .padding(.top, 5)
                    }
                } else {
                    // --- No Store Associated ---
                    Text("No vector store associated for File Search.")
                        .foregroundColor(.secondary)
                        .italic()
                    // Button to reveal association options.
                    Button {
                        showAssociationOptions.toggle()
                    } label: {
                        Label("Associate a Vector Store", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.blue)
                }
            }
            .padding(.vertical, 8)

            // --- Association Options (Conditional) ---
            // Show if no store is associated OR if user explicitly toggles options.
            if primaryVectorStoreId == nil || showAssociationOptions {
                // Section to create a new Vector Store.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create & Associate New").font(.subheadline).bold()
                    HStack {
                        Image(systemName: "square.and.pencil").foregroundColor(.secondary)
                        TextField("New Vector Store Name", text: $vectorStoreName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    Button(action: onCreateVectorStore) {
                        Label("Create and Associate", systemImage: "plus.app.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(.green)  // Less prominent than primary action
                    .disabled(vectorStoreName.isEmpty)  // Disable if name is empty
                }
                .padding(.vertical, 8)

                // Section for manual association using an existing ID.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Associate Existing by ID").font(.subheadline).bold()
                    HStack {
                        Image(systemName: "link").foregroundColor(.secondary)
                        TextField("Existing Vector Store ID", text: $vectorStoreIdToAssociate)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    Button {
                        viewModel.saveVectorStoreId(vectorStoreIdToAssociate)
                        vectorStoreIdToAssociate = ""  // Clear field after associating
                        showAssociationOptions = false  // Hide options after associating
                    } label: {
                        Label("Associate This ID", systemImage: "link.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(.orange)  // Different color for distinction
                    .disabled(vectorStoreIdToAssociate.isEmpty)  // Disable if ID is empty
                }
                .padding(.vertical, 8)
            }
            // Button to explicitly show/hide association options if a store is already associated.
            else if primaryVectorStoreId != nil {
                Button {
                    showAssociationOptions.toggle()
                } label: {
                    Label(
                        showAssociationOptions
                            ? "Hide Association Options" : "Associate Different Store",
                        systemImage: showAssociationOptions
                            ? "chevron.up.square" : "chevron.down.square"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 5)
            }
        }
    }

    // MARK: - Helper Views and Functions

    /// Helper View for displaying labeled information rows with an icon.
    private struct InfoRow: View {
        let label: String
        let value: String
        let icon: String
        var truncate: Text.TruncationMode = .tail

        var body: some View {
            HStack {
                Label(label, systemImage: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)  // Consistent label width
                Text(value)
                    .lineLimit(1)  // Prevent wrapping
                    .truncationMode(truncate)  // Apply truncation mode
                Spacer()
            }
            .font(.subheadline)
        }
    }

    /// Formats an integer timestamp into a readable date and time string.
    /// - Parameter timestamp: The Unix timestamp (seconds since epoch).
    /// - Returns: A formatted date string (e.g., "Apr 29, 2025, 10:30 AM") or "N/A".
    private func formattedDate(from timestamp: Int?) -> String {
        guard let timestamp = timestamp else { return "N/A" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
