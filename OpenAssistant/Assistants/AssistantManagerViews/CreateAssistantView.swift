import SwiftUI

struct CreateAssistantView: View {
    @ObservedObject var viewModel: AssistantManagerViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false

    // State variables for the assistant fields
    @State private var name: String = ""
    @State private var instructions: String = ""
    @State private var model: String = ""
    @State private var description: String = "You are a helpful assistant."
    @State private var temperature: Double = 1.0
    @State private var topP: Double = 1.0
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
                enableFileSearch: $enableFileSearch,
                enableCodeInterpreter: $enableCodeInterpreter,
                availableModels: viewModel.availableModels,
                isEditing: false,
                onSave: handleSave
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
            }
        }
    }

    private func handleSave() {
        if validateAssistant() {
            viewModel.createAssistant(
                model: model,
                name: name,
                description: description.isEmpty ? nil : description,
                instructions: instructions.isEmpty ? nil : instructions,
                tools: createTools(),
                toolResources: createToolResources(),
                metadata: nil,
                temperature: temperature,
                topP: topP,
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

    private func createTools() -> [Tool] {
        var tools: [Tool] = []
        if enableFileSearch { tools.append(Tool(type: "file_search")) }
        if enableCodeInterpreter { tools.append(Tool(type: "code_interpreter")) }
        return tools
    }

    private func createToolResources() -> ToolResources? {
        var toolResources = ToolResources()
        if enableFileSearch {
            toolResources.fileSearch = FileSearchResources(vectorStoreIds: ["valid_vector_store_id"])
        }
        if enableCodeInterpreter {
            toolResources.codeInterpreter = CodeInterpreterResources(fileIds: ["valid_file_id"])
        }
        return toolResources
    }

    private func dismissView() {
        presentationMode.wrappedValue.dismiss()
    }
}
