import Foundation
import Combine
import SwiftUI

struct CreateAssistantView: View {
    @ObservedObject var viewModel: AssistantManagerViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false
    
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
            Form {
                assistantDetailsSection
                toolsSection
            }
            .navigationTitle("Create Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        handleSave()
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Validation Error"), message: Text("Please fill in all required fields."), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                viewModel.fetchAvailableModels()
            }
        }
    }
    
    private var assistantDetailsSection: some View {
        Section(header: Text("Assistant Details")) {
            TextField("Name", text: $name)
            TextField("Instructions", text: $instructions)
            Picker("Model", selection: $model) {
                ForEach(viewModel.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .pickerStyle(MenuPickerStyle())
            TextField("Description", text: $description)
            temperatureSlider
            topPSlider
        }
    }
    
    private var toolsSection: some View {
        Section(header: Text("Tools")) {
            Toggle("Enable File Search", isOn: $enableFileSearch)
            Toggle("Enable Code Interpreter", isOn: $enableCodeInterpreter)
        }
    }
    
    private var temperatureSlider: some View {
        VStack {
            Text("Temperature: \(temperature, specifier: "%.2f")")
            Slider(value: $temperature, in: 0.0...2.0, step: 0.01)
        }
    }
    
    private var topPSlider: some View {
        VStack {
            Text("Top P: \(topP, specifier: "%.2f")")
            Slider(value: $topP, in: 0.0...1.0, step: 0.01)
        }
    }
    
    private func handleSave() {
        if validateAssistant() {
            let tools = createTools()
            let toolResources = createToolResources()
            viewModel.createAssistant(
                model: model,
                name: name,
                description: description.isEmpty ? nil : description,
                instructions: instructions.isEmpty ? nil : instructions,
                tools: tools,
                toolResources: toolResources,
                metadata: nil,
                temperature: temperature,
                topP: topP,
                responseFormat: nil
            )
            presentationMode.wrappedValue.dismiss()
        } else {
            showAlert = true
        }
    }
    
    private func validateAssistant() -> Bool {
        return !name.isEmpty && !model.isEmpty
    }
    
    private func createTools() -> [Tool] {
        var tools: [Tool] = []
        if enableFileSearch {
            tools.append(Tool(type: "file_search"))
        }
        if enableCodeInterpreter {
            tools.append(Tool(type: "code_interpreter"))
        }
        return tools
    }
    
    private func createToolResources() -> ToolResources? {
        var toolResources = ToolResources()
        if enableFileSearch {
            toolResources.fileSearch = FileSearchResources(vectorStoreIds: ["your_vector_store_id"])
        }
        if enableCodeInterpreter {
            toolResources.codeInterpreter = CodeInterpreterResources(fileIds: ["your_file_id"])
        }
        return toolResources
    }
}