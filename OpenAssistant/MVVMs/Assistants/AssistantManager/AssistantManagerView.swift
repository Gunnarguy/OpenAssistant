import Combine
import Foundation
import SwiftUI

struct AssistantManagerView: View {
    @EnvironmentObject var viewModel: AssistantManagerViewModel
    @State private var showingCreateAssistantSheet = false

    var body: some View {
        NavigationView {
            assistantList
                .navigationTitle("Manage Assistants")
                .toolbar {
                    addButton
                }
        }
        .onAppear {
            viewModel.fetchAssistants()
            // Observers might be better handled within the ViewModel's init or a dedicated setup method
            // viewModel.setupNotificationObservers() // Ensure observers are set up if needed here
        }
        // Group notification receivers for clarity
        .onReceive(NotificationCenter.default.publisher(for: .settingsUpdated)) { _ in
            viewModel.fetchAssistants()  // Refresh on settings change
        }
        .onReceive(NotificationCenter.default.publisher(for: .assistantCreated)) { _ in
            viewModel.fetchAssistants()  // Refresh when an assistant is created
        }
        .onReceive(NotificationCenter.default.publisher(for: .assistantUpdated)) { _ in
            viewModel.fetchAssistants()  // Refresh when an assistant is updated
        }
        .onReceive(NotificationCenter.default.publisher(for: .assistantDeleted)) { _ in
            viewModel.fetchAssistants()  // Refresh when an assistant is deleted
        }
        .sheet(
            isPresented: $showingCreateAssistantSheet,
            onDismiss: {
                // No need to fetch here if the create/update notifications handle it
                // viewModel.fetchAssistants()
            }
        ) {
            CreateAssistantView(viewModel: viewModel)
        }
    }

    private var assistantList: some View {
        List {  // Use List with ForEach for delete functionality if needed later
            if viewModel.assistants.isEmpty && viewModel.isLoading {
                ProgressView("Loading Assistants...")  // Show loading indicator
            } else if viewModel.assistants.isEmpty {
                Text("No assistants found. Tap '+' to create one.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.assistants) { assistant in
                    NavigationLink(
                        destination: AssistantDetailView(
                            assistant: assistant, managerViewModel: viewModel)
                    ) {
                        // Enhanced List Row Content
                        HStack {
                            VStack(alignment: .leading) {
                                Text(assistant.name).font(.headline)
                                Text(assistant.model)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let description = assistant.description, !description.isEmpty {
                                    Text(description)
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)  // Show only one line of description
                                }
                            }
                            Spacer()
                            // Optionally add icons for tools enabled
                            HStack(spacing: 4) {
                                if assistant.tools.contains(where: { $0.type == "file_search" }) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .foregroundColor(.blue)
                                }
                                if assistant.tools.contains(where: { $0.type == "code_interpreter" }
                                ) {
                                    Image(systemName: "curlybraces.square")
                                        .foregroundColor(.orange)
                                }
                            }
                            .font(.caption)  // Make tool icons smaller
                        }
                        .padding(.vertical, 4)  // Add slight vertical padding
                    }
                }
                // Add .onDelete if swipe-to-delete is desired
                // .onDelete(perform: deleteAssistant)
            }
        }
    }

    // Optional: Add delete function if using .onDelete
    /*
    private func deleteAssistant(at offsets: IndexSet) {
        offsets.map { viewModel.assistants[$0] }.forEach { assistant in
            viewModel.deleteAssistant(assistant: assistant)
        }
    }
    */

    private var addButton: some View {
        Button {
            showingCreateAssistantSheet = true
        } label: {
            Label("Create Assistant", systemImage: "plus.circle.fill")  // Use Label
        }
    }
}

// Removed initial duplicate AssistantManagerView_Previews block

// MARK: - Preview
/// Provides a preview of AssistantManagerView with sample data
struct AssistantManagerView_Previews: PreviewProvider {
    static var previews: some View {
        // Create and configure a sample view model
        let viewModel = AssistantManagerViewModel()
        viewModel.assistants = [
            Assistant(
                id: "1",
                object: "assistant",
                created_at: Int(Date().timeIntervalSince1970),
                name: "Preview Assistant 1",
                description: "A preview assistant example.",
                model: "preview-model",
                vectorStoreId: nil,
                instructions: nil,
                threads: nil,
                tools: [],
                top_p: 1.0,
                temperature: 0.7,
                reasoning_effort: nil,
                tool_resources: nil,
                metadata: nil,
                response_format: nil,
                file_ids: []
            )
        ]
        // Return the view with sample data environment
        return AssistantManagerView()
            .environmentObject(viewModel)
    }
}
