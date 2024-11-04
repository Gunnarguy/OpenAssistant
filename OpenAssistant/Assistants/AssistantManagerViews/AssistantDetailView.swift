import Foundation
import SwiftUI
import Combine

struct AssistantDetailView: View {
    @StateObject private var viewModel: AssistantDetailViewModel
    @ObservedObject var managerViewModel: AssistantManagerViewModel
    @State private var refreshTrigger = false
    @Environment(\.presentationMode) var presentationMode

    // Custom initializer for injecting the Assistant and ManagerViewModel
    init(assistant: Assistant, managerViewModel: AssistantManagerViewModel) {
        _viewModel = StateObject(wrappedValue: AssistantDetailViewModel(assistant: assistant))
        self.managerViewModel = managerViewModel
    }

    var body: some View {
        VStack {
            errorMessageView
            assistantDetailsView
            // Assistant details section with model picker
            AssistantDetailsSection(assistant: $viewModel.assistant, availableModels: managerViewModel.availableModels)
            actionButtonsView
        }
        .padding()
        .id(refreshTrigger)
        .onReceive(NotificationCenter.default.publisher(for: .assistantUpdated)) { notification in
            handleAssistantUpdated(notification: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .assistantDeleted)) { notification in
            handleAssistantDeleted(notification: notification)
        }
    }

    // Error message view for displaying validation or API errors
    @ViewBuilder
    private var errorMessageView: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage.message)
                .foregroundColor(.red)
                .padding()
                .multilineTextAlignment(.center)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        viewModel.errorMessage = nil
                    }
                }
        }
    }

    // Assistant details header, displaying the name
    private var assistantDetailsView: some View {
        Text("Details for \(viewModel.assistant.name)")
            .font(.title)
            .padding()
    }
    
    // Action buttons to update or delete the assistant
    private var actionButtonsView: some View {
        ActionButtonsView(
            refreshTrigger: $refreshTrigger,
            updateAction: {
                viewModel.updateAssistant()
                triggerRefresh()
            },
            deleteAction: {
                viewModel.deleteAssistant()
                triggerRefresh()
            }
        )
    }

    // Toggle refreshTrigger to update the view
    private func triggerRefresh() {
        refreshTrigger.toggle()
    }

    // Handler for assistant update notifications
    private func handleAssistantUpdated(notification: Notification) {
        if let updatedAssistant = notification.object as? Assistant, updatedAssistant.id == viewModel.assistant.id {
            viewModel.assistant = updatedAssistant
            triggerRefresh()
        }
    }

    // Handler for assistant deletion notifications
    private func handleAssistantDeleted(notification: Notification) {
        if let deletedAssistant = notification.object as? Assistant, deletedAssistant.id == viewModel.assistant.id {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct AssistantDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let assistant = Assistant(
            id: "1",
            object: "assistant",
            created_at: Int(Date().timeIntervalSince1970),
            name: "Test Assistant",
            description: "This is a test assistant.",
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
        let managerViewModel = AssistantManagerViewModel()
        
        // Initialize the view with the assistant and managerViewModel
        AssistantDetailView(assistant: assistant, managerViewModel: managerViewModel)
    }
}
