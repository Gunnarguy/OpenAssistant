import Foundation
import Combine
import SwiftUI

struct UpdateAssistantView: View {
    @ObservedObject var viewModel: AssistantManagerViewModel
    @StateObject private var assistantDetailViewModel: AssistantDetailViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false
    
    init(viewModel: AssistantManagerViewModel, assistant: Assistant) {
        self.viewModel = viewModel
        _assistantDetailViewModel = StateObject(wrappedValue: AssistantDetailViewModel(assistant: assistant))
    }
    
    var body: some View {
        NavigationView {
            Form {
                assistantDetailsSection
                toolsSection
            }
            .navigationTitle("Update Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismissView()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { handleSave() }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Validation Error"), message: Text("Please fill in all required fields."), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private var assistantDetailsSection: some View {
        Section(header: Text("Assistant Details")) {
            TextField("Name", text: $assistantDetailViewModel.assistant.name)
            TextField("Instructions", text: Binding($assistantDetailViewModel.assistant.instructions, default: ""))
            modelPicker
            TextField("Description", text: Binding($assistantDetailViewModel.assistant.description, default: ""))
            temperatureSlider
            topPSlider
        }
    }
    
    private var modelPicker: some View {
        Picker("Model", selection: $assistantDetailViewModel.assistant.model) {
            ForEach(viewModel.availableModels, id: \.self) { model in
                Text(model).tag(model)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }
    
    private var toolsSection: some View {
        Section(header: Text("Tools")) {
            Toggle("Enable File Search", isOn: Binding(
                get: { assistantDetailViewModel.assistant.tools.contains(where: { $0.type == "file_search" }) },
                set: { isEnabled in updateToolState(isEnabled: isEnabled, type: "file_search") }
            ))
            Toggle("Enable Code Interpreter", isOn: Binding(
                get: { assistantDetailViewModel.assistant.tools.contains(where: { $0.type == "code_interpreter" }) },
                set: { isEnabled in updateToolState(isEnabled: isEnabled, type: "code_interpreter") }
            ))
        }
    }
    
    private func updateToolState(isEnabled: Bool, type: String) {
        if isEnabled {
            if !assistantDetailViewModel.assistant.tools.contains(where: { $0.type == type }) {
                assistantDetailViewModel.assistant.tools.append(Tool(type: type))
            }
        } else {
            assistantDetailViewModel.assistant.tools.removeAll(where: { $0.type == type })
        }
    }
    
    private var temperatureSlider: some View {
        VStack {
            Text("Temperature: \(assistantDetailViewModel.assistant.temperature, specifier: "%.2f")")
            Slider(value: $assistantDetailViewModel.assistant.temperature, in: 0.0...2.0, step: 0.01)
        }
    }
    
    private var topPSlider: some View {
        VStack {
            Text("Top P: \(assistantDetailViewModel.assistant.top_p, specifier: "%.2f")")
            Slider(value: $assistantDetailViewModel.assistant.top_p, in: 0.0...1.0, step: 0.01)
        }
    }
    
    private func handleSave() {
        if validateAssistant() {
            viewModel.updateAssistant(assistant: assistantDetailViewModel.assistant)
            dismissView()
        } else {
            showAlert = true
        }
    }
    
    private func validateAssistant() -> Bool {
        !assistantDetailViewModel.assistant.name.isEmpty && !assistantDetailViewModel.assistant.model.isEmpty
    }
    
    private func dismissView() {
        DispatchQueue.main.async {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
