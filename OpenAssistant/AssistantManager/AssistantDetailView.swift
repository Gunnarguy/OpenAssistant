import Foundation
import SwiftUI
import Combine

struct AssistantDetailView: View {
    @StateObject private var viewModel: AssistantDetailViewModel
    @ObservedObject var managerViewModel: AssistantManagerViewModel
    @State private var refreshTrigger = false
    @Environment(\.presentationMode) var presentationMode

    init(assistant: Assistant, managerViewModel: AssistantManagerViewModel) {
        _viewModel = StateObject(wrappedValue: AssistantDetailViewModel(assistant: assistant))
        self.managerViewModel = managerViewModel
    }

    var body: some View {
        VStack {
            errorMessageView
            assistantDetailsView
            FormFieldsView(assistant: $viewModel.assistant, viewModel: managerViewModel)
            SlidersView(assistant: $viewModel.assistant)
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

    @ViewBuilder
    private var errorMessageView: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
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

    private var assistantDetailsView: some View {
        Text("Details for \(viewModel.assistant.name)")
            .font(.title)
            .padding()
    }

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

    private func triggerRefresh() {
        refreshTrigger.toggle()
    }

    private func handleAssistantUpdated(notification: Notification) {
        if let updatedAssistant = notification.object as? Assistant, updatedAssistant.id == viewModel.assistant.id {
            viewModel.assistant = updatedAssistant
            triggerRefresh()
        }
    }

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
            file_ids: [] // Provide an empty array or appropriate file IDs
        )
        let managerViewModel = AssistantManagerViewModel()
        AssistantDetailView(assistant: assistant, managerViewModel: managerViewModel)
    }
}
