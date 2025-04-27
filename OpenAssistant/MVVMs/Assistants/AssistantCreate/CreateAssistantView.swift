import Combine
import Foundation
import SwiftUI

struct CreateAssistantView: View {
    @ObservedObject var viewModel: AssistantManagerViewModel
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("OpenAI_Default_Model") private var defaultModel: String = ""
    @State private var showAlert: Bool = false

    // State variables for the assistant fields
    @State private var name: String = ""
    @State private var instructions: String = ""
    @State private var model: String = ""
    @State private var description: String = Constants.defaultDescription
    @State private var temperature: Double = Constants.defaultTemperature
    @State private var topP: Double = Constants.defaultTopP
    @State private var reasoningEffort: String = Constants.defaultReasoningEffort
    // Add state for tool toggles
    @State private var enableFileSearch: Bool = false
    @State private var enableCodeInterpreter: Bool = false

    var body: some View {
        NavigationView {
            AssistantFormView(
                name: $name,
                instructions: $instructions,
                model: $model,
                description: $description,
                temperature: $temperature,
                topP: $topP,
                reasoningEffort: $reasoningEffort,
                // Pass actual bindings for tools
                enableFileSearch: $enableFileSearch,
                enableCodeInterpreter: $enableCodeInterpreter,
                availableModels: viewModel.availableModels,
                isEditing: false, // Explicitly false for creation
                onSave: handleSave
                // onDelete is nil by default, appropriate for creation
            )
            .navigationTitle("Create Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismissView()
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Validation Error"),
                    message: Text("Please fill in all required fields."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                viewModel.fetchAvailableModels()
                // After fetching, default to stored defaultModel if valid, otherwise first valid model
                if model.isEmpty {
                    // Use all available models, not just reasoning models
                    if !defaultModel.isEmpty && viewModel.availableModels.contains(defaultModel) {
                        model = defaultModel
                    } else if let first = viewModel.availableModels.first {
                        model = first
                        defaultModel = first  // update stored default to new valid model
                    }
                }
            }
            .onChange(of: viewModel.availableModels) { models in
                // When models change, ensure current model is valid (any model)
                if !models.contains(model), let first = models.first {
                    model = first
                    defaultModel = first
                }
            }
        }
    }

    private func handleSave() {
        if validateAssistant() {
            // Construct the tools array based on the toggle states
            var tools: [Tool] = []
            if enableFileSearch {
                tools.append(Tool(type: "file_search"))
            }
            if enableCodeInterpreter {
                tools.append(Tool(type: "code_interpreter"))
            }

            // Determine parameters based on model type
            let isOModel = BaseViewModel.isReasoningModel(model)
            let tempToSend = isOModel ? Constants.defaultTemperature : temperature // Use default if O-model
            let topPToSend = isOModel ? Constants.defaultTopP : topP // Use default if O-model
            let reasoningToSend = isOModel ? reasoningEffort : nil // Use state if O-model, else nil

            viewModel.createAssistant(
                model: model,
                name: name,
                description: description.isEmpty ? nil : description,
                instructions: instructions.isEmpty ? nil : instructions,
                tools: tools, // Pass the constructed tools array
                toolResources: nil, // Tool resources are managed later
                metadata: nil,
                temperature: tempToSend,
                topP: topPToSend,
                reasoningEffort: reasoningToSend,
                responseFormat: nil
            )
            dismissView()
        } else {
            showAlert = true
        }
    }

    private func validateAssistant() -> Bool {
        !name.isEmpty && !model.isEmpty
    }

    private func dismissView() {
        presentationMode.wrappedValue.dismiss()
    }
}

private struct Constants {
    static let defaultDescription = "You are a helpful assistant."
    static let defaultTemperature: Double = 1.0
    static let defaultTopP: Double = 1.0
    static let defaultReasoningEffort = "medium"
    static let validVectorStoreId = "valid_vector_store_id"
    static let validFileId = "valid_file_id"
}
