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
            if let updatedAssistant = notification.object as? Assistant, updatedAssistant.id == viewModel.assistant.id {
                viewModel.assistant = updatedAssistant
                triggerRefresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .assistantDeleted)) { notification in
            if let deletedAssistant = notification.object as? Assistant, deletedAssistant.id == viewModel.assistant.id {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    @ViewBuilder
    private var errorMessageView: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .padding()
                .multilineTextAlignment(.center)
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
}