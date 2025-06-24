import Combine
import Foundation
import SwiftUI

struct AssistantManagerView: View {
    @EnvironmentObject var viewModel: AssistantManagerViewModel
    @State private var showingCreateAssistantSheet = false

    var body: some View {
        NavigationStack {
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

// MARK: - Preview
/// Provides a preview of AssistantManagerView with sample data
struct AssistantManagerView_Previews: PreviewProvider {
    // Create sample assistant data
    static let sampleAssistants = [
        Assistant(
            id: "preview-1",
            object: "assistant",
            created_at: Int(Date().timeIntervalSince1970),
            name: "General Assistant",
            description: "A general-purpose assistant for everyday tasks.",
            model: "gpt-4",
            vectorStoreId: nil,
            instructions: "You are a helpful assistant designed to assist with general tasks.",
            threads: nil,
            tools: [Tool(type: "file_search")],
            top_p: 1.0,
            temperature: 0.7,
            reasoning_effort: nil,
            tool_resources: nil,
            metadata: nil,
            response_format: nil,
            file_ids: []
        ),
        Assistant(
            id: "preview-2",
            object: "assistant",
            created_at: Int(Date().timeIntervalSince1970 - 86400),
            name: "Code Helper",
            description: "Specialized in programming assistance.",
            model: "o1",
            vectorStoreId: nil,
            instructions: "You are a specialized assistant for coding help.",
            threads: nil,
            tools: [Tool(type: "code_interpreter")],
            top_p: 1.0,
            temperature: 0.7,
            reasoning_effort: "high",
            tool_resources: nil,
            metadata: nil,
            response_format: nil,
            file_ids: []
        ),
    ]

    static var previews: some View {
        Group {
            // Light mode preview
            AssistantManagerView()
                .environmentObject(createViewModel())
                .previewDisplayName("Light Mode")

            // Dark mode preview
            AssistantManagerView()
                .environmentObject(createViewModel())
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }

    // Helper function to create and configure the view model
    private static func createViewModel() -> AssistantManagerViewModel {
        let viewModel = AssistantManagerViewModel()
        viewModel.assistants = sampleAssistants
        return viewModel
    }
}
