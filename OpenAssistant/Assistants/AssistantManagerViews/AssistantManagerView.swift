import Foundation
import Combine
import SwiftUI

struct AssistantManagerView: View {
    @StateObject private var viewModel = AssistantManagerViewModel()
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
            viewModel.setupNotificationObservers() // Ensure observers are set up
        }
        .onReceive(NotificationCenter.default.publisher(for: .assistantCreated), perform: handleAssistantCreated)
        .onReceive(NotificationCenter.default.publisher(for: .settingsUpdated)) { _ in
            viewModel.fetchAssistants()
        }
        .sheet(isPresented: $showingCreateAssistantSheet) {
            CreateAssistantView(viewModel: viewModel)
        }
    }

    private var assistantList: some View {
        List(viewModel.assistants) { assistant in
            NavigationLink(destination: AssistantDetailView(assistant: assistant, managerViewModel: viewModel)) {
                Text(assistant.name)
            }
        }
    }

    private var addButton: some View {
        Button(action: {
            showingCreateAssistantSheet = true
        }) {
            Image(systemName: "plus")
        }
    }

    private func handleAssistantCreated(notification: Notification) {
        if let createdAssistant = notification.object as? Assistant {
            viewModel.assistants.append(createdAssistant)
        }
    }
}

struct AssistantManagerView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = AssistantManagerViewModel()
        viewModel.assistants = [
            Assistant(
                id: "1",
                object: "assistant",
                created_at: Int(Date().timeIntervalSince1970),
                name: "Test Assistant 1",
                description: "This is a test assistant 1.",
                model: "test-model",
                instructions: nil,
                threads: nil,
                tools: [],
                top_p: 1.0,
                temperature: 0.7,
                tool_resources: nil,
                metadata: nil,
                response_format: nil,
                file_ids: []
            ),
            Assistant(
                id: "2",
                object: "assistant",
                created_at: Int(Date().timeIntervalSince1970),
                name: "Test Assistant 2",
                description: "This is a test assistant 2.",
                model: "test-model",
                instructions: nil,
                threads: nil,
                tools: [],
                top_p: 1.0,
                temperature: 0.7,
                tool_resources: nil,
                metadata: nil,
                response_format: nil,
                file_ids: []
            )
        ]
        return AssistantManagerView()
            .environmentObject(viewModel)
    }
}
