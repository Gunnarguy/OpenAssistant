import Foundation
import SwiftUI
import Combine

struct AssistantDetailView: View {
    @StateObject private var viewModel: AssistantDetailViewModel
    
    init(assistant: Assistant) {
        _viewModel = StateObject(wrappedValue: AssistantDetailViewModel(assistant: assistant))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if let errorMessage = viewModel.errorMessage {
                    Text(" \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                Text("Details for \(viewModel.assistant.name)")
                    .font(.title)
                    .padding()
                FormFieldsView(assistant: $viewModel.assistant)
                SlidersView(assistant: $viewModel.assistant)
                ActionButtonsView(
                    updateAction: viewModel.updateAssistant,
                    deleteAction: viewModel.deleteAssistant
                )
            }
            .padding()
        }
        .onReceive(NotificationCenter.default.publisher(for: .assistantDeleted)) { _ in
            viewModel.handleError("Assistant deleted successfully")
        }
    }
}
