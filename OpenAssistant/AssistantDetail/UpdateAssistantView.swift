import Foundation
import Combine
import SwiftUI

struct UpdateAssistantView: View {
    @StateObject private var viewModel: AssistantDetailViewModel
    
    
    init(assistant: Assistant) {
        _viewModel = StateObject(wrappedValue: AssistantDetailViewModel(assistant: assistant))
    }
    
    var body: some View {
        VStack {
            if let errorMessage = viewModel.errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
                    .multilineTextAlignment(.center)
            }
            Text("Update Assistant")
                .font(.title)
                .padding()
            FormFieldsView(assistant: $viewModel.assistant)
            SlidersView(assistant: $viewModel.assistant)
            ActionButtonsView(updateAction: viewModel.updateAssistant, deleteAction: viewModel.deleteAssistant)
        }
        .padding()
    }
}
